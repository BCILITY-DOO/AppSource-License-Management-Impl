table 90100 "BCY Setup"
{
    Caption = 'Impl Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(2; "Is License Active"; Boolean)
        {
            Caption = 'Is License Active';
        }
        field(3; "Last License Check"; Date)
        {
            Caption = 'Last License Check';
        }
        field(4; "License Valid Until"; Date)
        {
            Caption = 'License Valid Until';
        }
        field(5; "Contact Email"; Text[150])
        {
            Caption = 'Contact E-Mail';
        }
    }
    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}