pageextension 50551 "BCY Customer List" extends "Customer List"
{
    trigger OnOpenPage()
    var
        LicenseValidation: Codeunit "BCY License Validation";
    begin
        LicenseValidation.SendNotification();
    end;
}
