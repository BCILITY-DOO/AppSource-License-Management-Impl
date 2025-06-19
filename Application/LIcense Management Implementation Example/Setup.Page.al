page 90100 "BCY Setup"
{
    ApplicationArea = All;
    Caption = 'Impl Setup';
    PageType = Card;
    SourceTable = "BCY Setup";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(General)
            {
                ShowCaption = false;

                field("Is License Valid"; Rec."Is License Active")
                {
                    ToolTip = 'Specifies the value of the Is License Valid field.';
                    Editable = false;
                }
                field("Last License Check"; Rec."Last License Check")
                {
                    ToolTip = 'Specifies the value of the Last License Check field.';
                    Editable = false;
                    Style = Favorable;
                    StyleExpr = Rec."Is License Active";
                }
                field("License Valid Until"; Rec."License Valid Until")
                {
                    ToolTip = 'Specifies the day the license expires.';
                    Editable = false;
                    Style = Favorable;
                    StyleExpr = Rec."Is License Active";
                }
                field(RemainingDays; RemainingDays)
                {
                    Caption = 'Remaining Days';
                    ToolTip = 'Specifies the number of days before you need to renew the license.';
                    Editable = false;
                    Style = Favorable;
                    StyleExpr = RemainingDays <> 0;
                    BlankZero = true;
                }
                field("Contact Email"; Rec."Contact Email")
                {
                    ToolTip = 'Specifies the value of the contact email field';
                    Editable = false;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(CheckLicenseValidity)
            {
                ApplicationArea = All;
                Caption = 'Check License Validity';
                ToolTip = 'Checks the validity of the license.';
                Image = ValidateEmailLoggingSetup;
                trigger OnAction()
                begin
                    LicenseValidation.CheckIsLicenseActive();
                    UpdateRemainingDays();
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin
        if Rec.IsEmpty() then
            Rec.Insert();
    end;

    trigger OnAfterGetRecord()
    begin
        Rec."Is License Active" := LicenseValidation.IsLicenseActive();
        Rec.Modify();
        UpdateRemainingDays();
    end;

    local procedure UpdateRemainingDays()
    begin
        if (Rec."License Valid Until" = 0D) then begin
            Clear(RemainingDays);
            exit;
        end;
        RemainingDays := Rec."License Valid Until" - Today();
    end;

    var
        LicenseValidation: Codeunit "BCY License Validation";
        RemainingDays: Integer;
}
