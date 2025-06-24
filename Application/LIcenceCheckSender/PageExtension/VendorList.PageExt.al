pageextension 50552 "BCY Vendor List" extends "Vendor List"
{
    trigger OnOpenPage()
    var
        LicenseValidation: Codeunit "BCY License Validation";
    begin
        LicenseValidation.SendNotification();
    end;
}
