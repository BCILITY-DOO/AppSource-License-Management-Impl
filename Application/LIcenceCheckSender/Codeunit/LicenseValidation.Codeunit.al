codeunit 50553 "BCY License Validation"
{
    trigger OnRun()
    begin
        CheckIsLicenseActive();
    end;

    internal procedure CheckIsLicenseActive(): Boolean
    var
        LicenseManagementSetup: Record "BCY Setup";
    begin
        LicenseManagementSetup.Get();
        if IsLicenseActive() and (LicenseManagementSetup."Last License Check" = Today()) then
            exit(true);
        exit(MakeAndSendLicenseCheck());
    end;

    local procedure MakeAndSendLicenseCheck(): Boolean
    var
        RequestMessage: HttpRequestMessage;
        ResponseText: Text;
    begin
        if not MakeHttpRequest(RequestMessage) then begin
            DisableLicense();
            exit(false);
        end;
        if not SendHttpRequest(RequestMessage, ResponseText) then begin
            DisableLicense();
            exit(false);
        end;
        exit(ReadDataFromResponseAndGetIsLicenseActive(ResponseText));
    end;

    internal procedure SendNotification()
    var
        LicenseManagementSetup: Record "BCY Setup";
        EndOfLicenseNotification: Notification;
        EndOfLicenseTextLbl: Label 'You have %1 days remaining before your %2 license expires, if you want to extend your license please contact us via E-mail: %3.', Comment = '%1= Number of remaining days, %2 = App Name, %3 = contact email';
    begin
        LicenseManagementSetup.Get();
        case LicenseManagementSetup."License Valid Until" = 0D of
            true:
                exit;
            false:
                if CheckIsLicenseActive() and (LicenseManagementSetup."License Valid Until" - Today() < 7) then begin
                    EndOfLicenseNotification.Message(StrSubstNo(EndOfLicenseTextLbl, LicenseManagementSetup."License Valid Until" - Today(), GetAppName(), LicenseManagementSetup."Contact Email"));
                    EndOfLicenseNotification.Scope := NotificationScope::LocalScope;
                    EndOfLicenseNotification.Send();
                end;
        end;
    end;

    local procedure DisableLicense()
    var
        LicenseManagementSetup: Record "BCY Setup";
    begin
        if IsolatedStorage.Contains('BCY_IsLicenseValid', DataScope::Module) then
            IsolatedStorage.Delete('BCY_IsLicenseValid', DataScope::Module);
        IsolatedStorage.Set('BCY_IsLicenseValid', 'false', DataScope::Module);
        LicenseManagementSetup.Get();
        LicenseManagementSetup."License Valid Until" := 0D;
        LicenseManagementSetup.Modify();
    end;

    local procedure ReadDataFromResponseAndGetIsLicenseActive(ResponseText: Text): Boolean
    var
        LicenseManagementSetup: Record "BCY Setup";
        Response: JsonObject;
    begin
        LicenseManagementSetup.Get();
        if not Response.ReadFrom(ResponseText) then
            exit(false);
        if not Response.ReadFrom(Response.GetText('value')) then
            exit(false);
        if IsolatedStorage.Contains('BCY_IsLicenseValid', DataScope::Module) then
            IsolatedStorage.Delete('BCY_IsLicenseValid', DataScope::Module);
        IsolatedStorage.Set('BCY_IsLicenseValid', Response.GetText('IsLicenseValid'), DataScope::Module);
        LicenseManagementSetup."Is License Active" := Response.GetBoolean('IsLicenseValid');
        case LicenseManagementSetup."Is License Active" of
            true:
                if Response.Contains('ValidUntil') then begin
                    if Today() < Response.GetDate('ValidUntil') then
                        LicenseManagementSetup."License Valid Until" := Response.GetDate('ValidUntil')
                    else
                        Clear(LicenseManagementSetup."License Valid Until");
                end else
                    Clear(LicenseManagementSetup."License Valid Until");
            false:
                Clear(LicenseManagementSetup."License Valid Until");
        end;
        LicenseManagementSetup."Contact Email" := Response.GetText('ContactEmail');
        LicenseManagementSetup."Last License Check" := Today();
        LicenseManagementSetup."License Type" := Response.GetText('LicenseType');
        LicenseManagementSetup.Modify();
        exit(LicenseManagementSetup."Is License Active");
    end;

    local procedure SendHttpRequest(var RequestMessage: HttpRequestMessage; var ResponseText: Text): Boolean
    var
        IsResponseSuccess: Boolean;
        Client: HttpClient;
        ResponseMessage: HttpResponseMessage;
    begin
        Clear(ResponseMessage);
        IsResponseSuccess := Client.Send(RequestMessage, ResponseMessage);
        if (not IsResponseSuccess) then
            Error(GetLastErrorText);
        ResponseMessage.Content.ReadAs(ResponseText);
        exit(IsResponseSuccess);
    end;

    [TryFunction]
    local procedure MakeHttpRequest(var RequestMessage: HttpRequestMessage)
    var
        Content: HttpContent;
        ContentHeaders, MessageHeaders : HttpHeaders;
        Request, URL : Text;
    begin
        URL := GetReceiverBCBaseAddress() + GetReceiverTenantGUID() + GetReceiverEnvironmentName() + GetODataLabel() + GetWebServiceName() + GetLicenseCheckProcedureName() + GetReceiverCompanyGUID();

        MakeSenderJSON().WriteTo(Request);
        Content.WriteFrom(Request);
        Content.GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        RequestMessage.SetRequestUri(URL);
        RequestMessage.Method('POST');
        RequestMessage.GetHeaders(MessageHeaders);
        MessageHeaders.Add('Authorization', SecretStrSubstNo('Bearer %1', GetOAuthToken()));
        RequestMessage.Content(Content);
    end;

    local procedure GetOAuthToken() AuthToken: SecretText
    var
        OAuth2: Codeunit OAuth2;
        FailedToGetAccessTokenErrLbl: Label 'Failed to get access token from response\%1', Comment = '%1 = Last Error Text';
        Scopes: List of [Text];
        AccessTokenURL, ClientID, ClientSecret : Text;
    begin
        ClientID := '...'; //TODO Add your client ID here
        ClientSecret := '...'; // TODO Add your client secret here
        AccessTokenURL := 'https://login.microsoftonline.com/' + GetTenantGUID() + '/oauth2/v2.0/token';
        Scopes.Add('https://api.businesscentral.dynamics.com/.default');
        if not OAuth2.AcquireTokenWithClientCredentials(ClientID, ClientSecret, AccessTokenURL, '', Scopes, AuthToken) then
            Error(FailedToGetAccessTokenErrLbl, GetLastErrorText());
    end;

    local procedure MakeSenderJSON() CompleteJSON: JsonObject
    var
        CompanyInformation: Record "Company Information";
        User: Record User;
        EnvironmentInformation: Codeunit "Environment Information";
        HelperVar: Text;
    begin
        CompanyInformation.Get();
        CompleteJSON.Add('AppGUID', DelChr(GetAppGUID(), '=', '{}'));
        CompleteJSON.Add('AppName', GetAppName());
        CompleteJSON.Add('BCVersion', GetCurrBCVersion());
        CompleteJSON.Add('AppVersion', EnvironmentInformation.VersionInstalled(GetAppGUID()));
        CompleteJSON.Add('TenantGUID', GetTenantGUID());
        CompleteJSON.Add('TenantName', GetTenantName());
        CompleteJSON.Add('Date', Today());
        CompleteJSON.Add('IsEnvironmentProduction', EnvironmentInformation.IsProduction());
        CompleteJSON.Add('EnvironmentName', EnvironmentInformation.GetEnvironmentName());
        CompleteJSON.Add('EnvironmentNumberOfUsers', User.Count());
        CompleteJSON.Add('CompanyName', CompanyName());
        CompleteJSON.Add('CompanyVATNo', CompanyInformation."VAT Registration No.");
        CompleteJSON.Add('CompanyAddress', CompanyInformation.Address);
        CompleteJSON.Add('CompanyCity', CompanyInformation.City);
        CompleteJSON.Add('CompanyCountryRegionCode', CompanyInformation."Country/Region Code");
        CompleteJSON.Add('CompanyPhoneNo', CompanyInformation."Phone No.");
        CompleteJSON.Add('CompanyEMail', CompanyInformation."E-Mail");
        CompleteJSON.WriteTo(HelperVar);
        Clear(CompleteJSON);
        CompleteJSON.Add('data', HelperVar);
    end;

    local procedure GetTenantGUID(): Text
    var
        AzureADTenant: Codeunit "Azure AD Tenant";
    begin
        exit(AzureADTenant.GetAadTenantId());
    end;

    local procedure GetAppGUID() AppGUID: Guid
    var
        ModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        AppGUID := ModuleInfo.Id();
    end;

    local procedure GetAppName() AppNAme: Text
    var
        modInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(modInfo);
        AppNAme := modInfo.Name();
    end;

    local procedure GetCurrBCVersion() AppVersion: Text
    var
        BaseAppID: Codeunit "BaseApp ID";
        Info: ModuleInfo;
    begin
        NavApp.GetModuleInfo(BaseAppID.Get(), Info);
        AppVersion := Format(Info.AppVersion());
    end;

    local procedure GetReceiverBCBaseAddress(): Text
    var
        BCBaseAddressLbl: Label 'https://api.businesscentral.dynamics.com/v2.0', Locked = true;
    begin
        exit(BCBaseAddressLbl);
    end;

    local procedure GetReceiverTenantGUID(): Text
    var
        TenantGUIDLbl: Label '...', Locked = true; //TODO Your Tenant GUID 
    begin
        exit('/' + TenantGUIDLbl);
    end;

    local procedure GetReceiverEnvironmentName(): Text
    var
        EnvironmentNameLbl: Label '...', Locked = true; //TODO Environment Name
    begin
        exit('/' + EnvironmentNameLbl);
    end;

    local procedure GetODataLabel(): Text
    var
        ODataLbl: Label 'ODataV4', Locked = true;
    begin
        exit('/' + ODataLbl);
    end;

    local procedure GetWebServiceName(): Text
    var
        WebServiceNameLbl: Label 'LicenseManagement', Locked = true;
    begin
        exit('/' + WebServiceNameLbl);
    end;

    local procedure GetLicenseCheckProcedureName(): Text
    var
        ProcedureNameLbl: Label 'CheckLicenseData', Locked = true;
    begin
        exit('_' + ProcedureNameLbl);
    end;

    local procedure GetReceiverCompanyGUID(): Text
    var
        CompanyGUIDLbl: Label '...', Locked = true; //TODO Receiver Company GUID
    begin
        exit('?company=' + CompanyGUIDLbl);
    end;

    local procedure GetTenantName(): Text
    var
        AzureADTenant: Codeunit "Azure AD Tenant";
    begin
        exit(AzureADTenant.GetAadTenantDomainName());
    end;

    internal procedure IsLicenseActive() Value: Boolean
    var
        Helper: Text;
    begin
        if not IsolatedStorage.Contains('License', DataScope::Module) then // You Can change the Isolated storage key  
            exit(false);
        IsolatedStorage.Get('License', DataScope::Module, Helper);
        Evaluate(Value, Helper);
    end;
}
