permissionset 50100 "BCY AppSource-Applic"
{
    Access = Internal;
    Assignable = true;
    Caption = 'BCY AppSource-Application-Template', Locked = true;
    Permissions =
codeunit "BCY License Validation" = X,
page "BCY Setup" = X,
table "BCY Setup" = X,
tabledata "BCY Setup" = RIMD;
}
