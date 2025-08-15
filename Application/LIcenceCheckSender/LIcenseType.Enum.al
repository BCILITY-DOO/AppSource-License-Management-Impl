enum 50100 "BCY License Type"
{
    Extensible = false;
    Access = Internal;

    value(0; "")
    {
        Caption = '', Locked = true;
    }
    value(1; Free)
    {
        Caption = 'Free';
    }
    value(2; Paid)
    {
        Caption = 'Paid';
    }
    value(3; "Free Trial")
    {
        Caption = 'Free Trial';
    }
    value(4; Expired)
    {
        Caption = 'Expired';
    }
}
