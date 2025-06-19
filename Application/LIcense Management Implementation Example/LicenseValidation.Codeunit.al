codeunit 90100 "BCY License Validation"
{
    trigger OnRun()
    begin
        CheckIsLicenseActive();
    end;

    internal procedure CheckIsLicenseActive(): Boolean
    begin
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

    local procedure DisableLicense()
    var
        Setup: Record "BCY Setup";
    begin
        if IsolatedStorage.Contains('BCY_IsLicenseValid', DataScope::Module) then
            IsolatedStorage.Delete('BCY_IsLicenseValid', DataScope::Module);
        IsolatedStorage.Set('BCY_IsLicenseValid', 'false', DataScope::Module);
        Setup.Get();
        Setup."License Valid Until" := 0D;
        Setup.Modify();
    end;

    local procedure ReadDataFromResponseAndGetIsLicenseActive(ResponseText: Text): Boolean
    var
        Setup: Record "BCY Setup";
        Response: JsonObject;
    begin
        Setup.Get();
        Response.ReadFrom(ResponseText);
        Response.ReadFrom(Response.GetText('value'));
        if IsolatedStorage.Contains('BCY_IsLicenseValid', DataScope::Module) then
            IsolatedStorage.Delete('BCY_IsLicenseValid', DataScope::Module);
        IsolatedStorage.Set('BCY_IsLicenseValid', Response.GetText('IsLicenseValid'), DataScope::Module);
        Setup."Is License Active" := Response.GetBoolean('IsLicenseValid');
        case Setup."Is License Active" of
            true:
                if Response.Contains('ValidUntil') then begin
                    if Today() < Response.GetDate('ValidUntil') then
                        Setup."License Valid Until" := Response.GetDate('ValidUntil')
                    else
                        Clear(Setup."License Valid Until");
                end else
                    Clear(Setup."License Valid Until");
            false:
                Clear(Setup."License Valid Until");
        end;
        Setup."Contact Email" := Response.GetText('ContactEmail');
        Setup."Last License Check" := Today();
        Setup.Modify();
        exit(Setup."Is License Active");
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
        ClientID := '...'; // Your Client ID
        ClientSecret := '...'; // Your Client Secret
        AccessTokenURL := 'https://login.microsoftonline.com/' + GetTenantGUID() + '/oauth2/v2.0/token';
        Scopes.Add('https://api.businesscentral.dynamics.com/.default');
        if not OAuth2.AcquireTokenWithClientCredentials(ClientID, ClientSecret, AccessTokenURL, '', Scopes, AuthToken) then
            Error(FailedToGetAccessTokenErrLbl, GetLastErrorText());
    end;

    local procedure MakeSenderJSON() CompleteJSON: JsonObject
    var
        EnvironmentInformation: Codeunit "Environment Information";
        HelperVar: Text;
    begin
        CompleteJSON.Add('AppGUID', DelChr(GetAppGUID(), '=', '{}'));
        CompleteJSON.Add('AppName', GetAppName());
        CompleteJSON.Add('BCVersion', GetCurrBCVersion());
        CompleteJSON.Add('AppVersion', EnvironmentInformation.VersionInstalled(GetAppGUID()));
        CompleteJSON.Add('TenantGUID', GetTenantGUID());
        CompleteJSON.Add('TenantName', GetTenantName());
        CompleteJSON.Add('Date', Today());
        CompleteJSON.Add('IsEnvironmentProduction', EnvironmentInformation.IsProduction());
        CompleteJSON.Add('EnvironmentName', EnvironmentInformation.GetEnvironmentName());
        CompleteJSON.Add('CustomerName', CompanyName());
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
        TenantGUIDLbl: Label '...', Locked = true; // Your Tenant GUID
    begin
        exit('/' + TenantGUIDLbl);
    end;

    local procedure GetReceiverEnvironmentName(): Text
    var
        EnvironmentNameLbl: Label 'Placeholder-Name', Locked = true; // Your Environment Name
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
        CompanyGUIDLbl: Label '...', Locked = true; // Your Company GUID
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
        if not IsolatedStorage.Contains('BCY_IsLicenseValid', DataScope::Module) then
            exit(false);
        IsolatedStorage.Get('BCY_IsLicenseValid', DataScope::Module, Helper);
        Evaluate(Value, Helper);
    end;
}
