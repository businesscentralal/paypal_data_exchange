codeunit 55202 "CSV Reader for Data Exchange"
{
    Permissions = TableData "Data Exch. Field" = rimd;
    TableNo = "Data Exch.";

    trigger OnRun()
    var
        ReadStream: InStream;
        ParentNodeId: Text[250];
        ReadText: Text;
        ReadLen: Integer;
        LineNo: Integer;
        SkippedLineNo: Integer;
    begin
        CalcFields("File Content");
        with DataExchDef do begin
            Get("Data Exch. Def Code");
            SetDelimiter();
            case "File Encoding" of
                "File Encoding"::"MS-DOS":
                    "File Content".CreateInStream(ReadStream, TEXTENCODING::MSDos);
                "File Encoding"::WINDOWS:
                    "File Content".CreateInStream(ReadStream, TEXTENCODING::Windows);
                "File Encoding"::"UTF-8":
                    "File Content".CreateInStream(ReadStream, TEXTENCODING::UTF8);
                "File Encoding"::"UTF-16":
                    "File Content".CreateInStream(ReadStream, TEXTENCODING::UTF16);
            end;
            repeat
                ReadLen := ReadStream.ReadText(ReadText);
                if ReadLen > 0 then
                    ParseLine(Rec, ReadText, ParentNodeId, LineNo, SkippedLineNo);
            until ReadLen = 0;
        end;
    end;

    var
        DataExchDef: Record "Data Exch. Def";
        LineDefBuffer: Record "Name/Value Buffer" temporary;
        Delimiters: Record "Integer" temporary;
        MissingColumnSeparatorTxt: Label '%1 is missing for %2 %3', Comment = 'Data Exchange Def., %1 = FieldCaption("Column Separator"), %2 = TableCaption(), %3 = Code';

    local procedure ParseLine(DataExch: Record "Data Exch."; Line: Text; var ParentNodeId: Text[250]; var LineNo: Integer; var SkippedLineNo: Integer)
    var
        Columns: Record "Name/Value Buffer" temporary;
        DataExchLineDef: Record "Data Exch. Line Def";
    begin
        if ((LineNo + SkippedLineNo) < DataExchDef."Header Lines") then begin
            SkippedLineNo += 1;
            exit;
        end;

        with DataExchLineDef do begin
            SetRange("Data Exch. Def Code", DataExch."Data Exch. Def Code");
            if not FindSet() then exit;

            if "Parent Code" = '' then
                LineNo += 1;

            while GetNextColumn(Line, Columns.Value) do begin
                Columns.ID += 1;
                Columns.Insert();
            end;

            repeat
                AddFields(DataExch, DataExchLineDef, Columns, ParentNodeId)
            until Next() = 0;
        end;
    end;

    local procedure AddFields(DataExch: Record "Data Exch."; DataExchLineDef: Record "Data Exch. Line Def"; var Columns: Record "Name/Value Buffer"; var ParentNodeId: Text[250])
    var
        DataExchColumnDef: Record "Data Exch. Column Def";
        DataExchField: Record "Data Exch. Field";
        NodeId: Text[250];
    begin
        with DataExchColumnDef do begin
            SetRange("Data Exch. Def Code", DataExch."Data Exch. Def Code");
            SetRange("Data Exch. Line Def Code", DataExchLineDef.Code);

            if DataExchLineDef."Parent Code" = '' then begin
                LineDefBuffer.SetFilter(Name, '<>%1', DataExchLineDef.Code);
                LineDefBuffer.DeleteAll();
            end;

            LineDefBuffer.ID += 1;
            LineDefBuffer.Name := DataExchLineDef.Code;
            LineDefBuffer.Insert();
            LineDefBuffer.SetRange(Name, DataExchLineDef.Code);

            NodeId := DelChr(CreateGuid(), '=', '{}');
            if Columns.Find('-') then
                repeat
                    Columns.Value := DelChr(DelChr(Columns.Value, '<', '"'), '>', '"');
                    SetRange("Column No.", Columns.ID);
                    SetRange(Constant, '');
                    if FindFirst() then
                        if DataExchLineDef."Parent Code" <> '' then
                            DataExchField.InsertRecXMLFieldWithParentNodeID(DataExch."Entry No.", LineDefBuffer.Count(), "Column No.", NodeId, ParentNodeId, Columns.Value, DataExchLineDef.Code)
                        else
                            DataExchField.InsertRecXMLField(DataExch."Entry No.", LineDefBuffer.Count(), "Column No.", NodeId, Columns.Value, DataExchLineDef.Code);
                until Columns.Next() = 0;

            SetRange("Column No.");
            SetFilter(Constant, '<>%1', '');
            if FindSet() then
                repeat
                    if DataExchLineDef."Parent Code" <> '' then
                        DataExchField.InsertRecXMLFieldWithParentNodeID(DataExch."Entry No.", LineDefBuffer.Count(), "Column No.", NodeId, ParentNodeId, Constant, DataExchLineDef.Code)
                    else
                        DataExchField.InsertRecXMLField(DataExch."Entry No.", LineDefBuffer.Count(), "Column No.", NodeId, Constant, DataExchLineDef.Code);
                until Next() = 0;

            if DataExchLineDef."Parent Code" = '' then
                ParentNodeId := NodeId;
        end;
    end;

    local procedure SetDelimiter()
    var
        Pos: Integer;
        Char: Integer;
    begin
        with DataExchDef do
            case "Column Separator" of
                "Column Separator"::Comma:
                    begin
                        Delimiters.Number := 44;
                        Delimiters.Insert();
                    end;
                "Column Separator"::Semicolon:
                    begin
                        Delimiters.Number := 59;
                        Delimiters.Insert();
                    end;
                "Column Separator"::Space:
                    begin
                        Delimiters.Number := 32;
                        Delimiters.Insert();
                    end;
                "Column Separator"::Tab:
                    begin
                        Delimiters.Number := 9;
                        Delimiters.Insert();
                    end;
                "Column Separator"::Custom:
                    for Pos := 1 to StrLen("Custom Column Separator") do begin
                        Char := "Custom Column Separator"[Pos];
                        Delimiters.Number := Char;
                        Delimiters.Insert();
                    end;
                else
                    Error(MissingColumnSeparatorTxt, FieldCaption("Column Separator"), TableCaption(), Code);
            end;
    end;

    local procedure GetNextColumn(var Line: Text; var ColumnValue: Text[250]): Boolean
    var
        Pos: Integer;
        Char: Char;
        InDoubleQuotes: Boolean;
    begin
        ColumnValue := '';
        if Line = '' then exit(false);
        for Pos := 1 to StrLen(Line) do begin
            Char := Line[Pos];
            if (Char = 34) then
                InDoubleQuotes := not InDoubleQuotes;
            Delimiters.SetRange(Number, Char);
            case true of
                InDoubleQuotes:
                    ColumnValue += Format(Char);
                else
                    if Delimiters.FindFirst() then begin
                        Line := CopyStr(Line, Pos + 1);
                        exit(true);
                    end else
                        ColumnValue += Format(Char);
            end;
        end;
        Line := '';
        exit(true);
    end;
}

