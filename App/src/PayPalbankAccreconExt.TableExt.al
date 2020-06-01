tableextension 55200 "PayPal Bank Acc.Recon Ext" extends "Bank Acc. Reconciliation Line"
{
    fields
    {
        field(55200; "O4N Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency;
        }
        field(55201; "O4N Balance"; Decimal)
        {
            AutoFormatExpression = "O4N Currency Code";
            AutoFormatType = 1;
            Caption = 'Balance';
            DataClassification = CustomerContent;
        }

    }
}
