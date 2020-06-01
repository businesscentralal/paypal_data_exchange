codeunit 55203 "PayPal Post-Map Process"
{
    TableNo = "Bank Acc. Reconciliation Line";

    trigger OnRun()
    var
    begin
        RemoveIncorrectCurrencyEntries(Rec);
        SetEndValues(Rec);
    end;

    local procedure RemoveIncorrectCurrencyEntries(var BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line"): Boolean
    var
        BankAccReconciliationLineToRemove: Record "Bank Acc. Reconciliation Line" temporary;
        BankAcc: Record "Bank Account";
    begin
        BankAcc.Get(BankAccReconciliationLine."Bank Account No.");
        if BankAcc."Currency Code" = '' then exit;
        BankAccReconciliationLineToRemove.Copy(BankAccReconciliationLine, true);
        BankAccReconciliationLineToRemove.SetFilter("O4N Currency Code", '<>%1', BankAcc."Currency Code");
        BankAccReconciliationLineToRemove.DeleteAll();
    end;

    local procedure SetEndValues(var BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line")
    var
        BankAccReconciliation: Record "Bank Acc. Reconciliation";
        LastBankAccReconciliationLine: Record "Bank Acc. Reconciliation Line" temporary;
    begin
        LastBankAccReconciliationLine.Copy(BankAccReconciliationLine, true);
        if LastBankAccReconciliationLine.FindLast() then begin
            BankAccReconciliation.Get(BankAccReconciliationLine."Statement Type", BankAccReconciliationLine."Bank Account No.", BankAccReconciliationLine."Statement No.");
            BankAccReconciliation."Statement Date" := LastBankAccReconciliationLine."Transaction Date";
            BankAccReconciliation."Statement Ending Balance" := LastBankAccReconciliationLine."O4N Balance";
            BankAccReconciliation.Modify();
        end;
    end;
}

