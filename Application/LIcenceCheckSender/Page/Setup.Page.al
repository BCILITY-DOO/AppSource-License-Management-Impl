page 50100 "BCY Setup"
{
    ApplicationArea = All;
    Caption = 'Setup';
    PageType = Card;
    SourceTable = "BCY Setup";
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

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
                field("License Type"; Rec."License Type")
                {
                    ToolTip = 'Specifies the value of the license type field.';
                    Editable = false;
                    StyleExpr = StyleExpr;
                }
                field("License Valid Until"; Rec."License Valid Until")
                {
                    ToolTip = 'Specifies the day the license expires.';
                    Editable = false;
                    StyleExpr = StyleExpr;
                }
                field(RemainingDays; RemainingDays)
                {
                    Caption = 'Remaining Days';
                    ToolTip = 'Specifies the number of days before you need to renew the license.';
                    Editable = false;
                    StyleExpr = StyleExpr;
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
                var
                    CheckCompletedLbl: Label 'License validity check completed.';
                begin
                    LicenseValidation.MakeAndSendLicenseCheck();
                    UpdateRemainingDays();
                    Message(CheckCompletedLbl);
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
        if Rec."Last License Check" = 0D then begin
            LicenseValidation.CheckIsLicenseActive();
            Rec.Find();
        end else
            Rec."Is License Active" := LicenseValidation.IsLicenseActive();
        Rec.Modify();
        UpdateRemainingDays();
        if Rec."Is License Active" then
            StyleExpr := Format(PageStyle::Favorable)
        else
            StyleExpr := Format(PageStyle::Unfavorable);
        CurrPage.Update(false);
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
        StyleExpr: Text;
}
