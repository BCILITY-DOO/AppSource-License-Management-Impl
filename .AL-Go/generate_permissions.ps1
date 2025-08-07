#Script scans all .al files in /src/ and generate PermissionSet object.
#Remark: Before running script, go to the folder where script is located

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
$ErrorActionPreference = 'Stop';

#Array per object type. Order: codeunit, page, query, report, table, tabledata, xmlport. Everything has only X tag, only tabledata has RIMD
$global:codeunitArray = @()
$global:pageArray = @()
$global:queryArray = @()
$global:reportArray = @()
$global:tableArray = @()
$global:tabledataArray = @()
$global:xmlportArray = @()


function Get-AppInfo {
    $appJsonPath = '..\Application\app.json'
    if (-not (Test-Path $appJsonPath)) {
        throw "app.json file not found at $appJsonPath"
    }
    
    $appJson = Get-Content $appJsonPath -Raw | ConvertFrom-Json
    
    # Get the first ID from idRanges
    $firstId = $appJson.idRanges[0].from
    
    # Get app name and create permission set name (max 20 chars)
    $appName = $appJson.name
    $permissionSetName = "BCY $appName"
    if ($permissionSetName.Length -gt 20) {
        $permissionSetName = $permissionSetName.Substring(0, 20)
    }
    
    # Caption can be full name
    $caption = "BCY $appName"
    
    return @{
        Id = $firstId
        Name = $permissionSetName
        Caption = $caption
        AppName = $appName
    }
}


function Get-ObjectType {
    param (
        [Parameter(Mandatory = $true)]
        [Object] $fileLines
    )    
    
    $objectDeclarations = $fileLines | Select-String -Pattern '^(codeunit|page|query|table|xmlport|report)[\s\n]*'
    if ($objectDeclarations.Matches.Groups.Count -eq 0) {
        return ""
    }
    else {
        $objectType = $objectDeclarations.Matches.Groups[1].Value    
        return $objectType
    }
    
}
function AddToArray {
    param (        
        [Parameter(Mandatory = $true)] $objectType,
        [Parameter(Mandatory = $true)] $fileName,
        [Parameter(Mandatory = $true)] $pragmaExist,
        [Parameter(Mandatory = $true)] $pragmaText
    )
    $valueToInsert = -join ($objectType, ' ', $fileName, ' = X,')
    if ($pragmaExist -eq 1) {
        $valueToInsert = -join $pragmaText, $valueToInsert, '#endif'
    }
    switch ($objectType) {
        "codeunit" { $global:codeunitArray += $valueToInsert }
        "query" { $global:queryArray += $valueToInsert }
        "table" { 
            $global:tableArray += $valueToInsert 
            $valueToInsert = -join ('tabledata ', $fileName, ' = RIMD,')
            if ($pragmaExist -eq 1) {
                $valueToInsert = -join $pragmaText, $valueToInsert, '#endif'
            }
            $global:tabledataArray += $valueToInsert 
        }
        "report" { $global:reportArray += $valueToInsert }
        "page" { $global:pageArray += $valueToInsert }
        "xmlport" { $global:xmlportArray += $valueToInsert }
    }
}

function Find-FirstOccurrenceOfProperty {
    param (        
        [Parameter(Mandatory = $true)]
        [Object] $file
    )
    [System.Collections.ArrayList]$fileLines = Get-Content -LiteralPath $file.FullName -Encoding UTF8;

    $lineCount = 0;

    foreach ($line in $fileLines) {  
        $lineCount += 1;
        if ($line -match "^.*=.*;$") {
            break;
        }
    }

    return $lineCount;
}

function Skip-ObsoletedObject {
    param (        
        [Parameter(Mandatory = $true)]
        [Object] $file
    )
    
    [System.Collections.ArrayList]$fileLines = Get-Content -LiteralPath $file.FullName -Encoding UTF8;

    $lineToStart = Find-FirstOccurrenceOfProperty $file
    $propertiesArray = @()

    for ($index = $lineToStart; $index -le $fileLines.Count; $index++) {

        $line = $fileLines[$index]

        if ($line -match "^.*#if*" -or $line -match "^.*#endif*" -or $line -match "^.*//*" -or [string]::IsNullOrWhiteSpace($line)) {
            continue;
        }

        if (-not ($line -match "^.*=.*$")) {
            break;
        }

        $property = $line -replace "\s","";

        $propertiesArray += $property;
    }

    if ($propertiesArray -contains "ObsoleteState=Removed;") {
        return $true;
    }
    return $false;
}

function AddFileToArray {
    param (        
        [Parameter(Mandatory = $true)]
        [Object] $file
    )

    if (Skip-ObsoletedObject $file)
    {
        return;
    }
           
    [System.Collections.ArrayList]$fileLines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
    $insertedObject = 0
    $pragmaExist = 0 
    $pragmaText = ''
    
    foreach ($line in $fileLines) {        
        $lineNumber += 1

        if ($line -match '^(\bcodeunit\b|\bpage\b|\bquery\b|\btable\b|\bxmlport\b|\breport\b)[\s\n]*') {
            $insertedObject = 1
            if(!($line -split '(?<=\d ")(.*?)(?=")')[1])
            {
                $fileName = '"' + ($line -split '(\s)')[4] + '"'
            } 
            else
            {
                $fileName = '"' + ($line -split '(?<=\d ")(.*?)(?=")')[1] + '"'
            }
            $objectType = Get-ObjectType $fileLines
                
            AddToArray $objectType $fileName $pragmaExist $pragmaText
        }
        elseif ($line -match '#if') {
            $pragmaExist = 1
            $pragmaText = $line
        }
        elseif ($line -match '^(\bpermissionset\b)[\s\n]*') {        
            $insertedObject = 1
        }
        if ($insertedObject -eq 1) {
            return
        }
    }    
}
function GeneratePermissionSetFile {
    $appInfo = Get-AppInfo
    
    $permissions = $global:codeunitArray + $global:pageArray + $global:queryArray + $global:reportArray + $global:tableArray + $global:tabledataArray + $global:xmlportArray
    $last = $permissions[$permissions.Count - 1] -replace ',', ';'
    $permissions = $permissions[0..($permissions.Count - 2)] + $last
    
    $permissionsObject = @()
    $permissionsObject += "permissionset $($appInfo.Id) `"$($appInfo.Name)`""
    $permissionsObject += '{'
    $permissionsObject += '    Access = Internal;'
    $permissionsObject += '    Assignable = true;'
    $permissionsObject += "    Caption = '$($appInfo.Caption)', Locked = true;"
    $permissionsObject += '    Permissions ='
    $permissionsObject += $permissions
    $permissionsObject += '}'

    # Create filename based on app name (sanitize for filename)
    $fileName = $appInfo.AppName -replace '[^\w\s-]', '' -replace '\s+', ''
    New-Item "..\Application\src\Permissions\$fileName.PermissionSet.al" -Force
    Set-Content "..\Application\src\Permissions\$fileName.PermissionSet.al" $permissionsObject
}


function runScript {
    $fileList = Get-ChildItem -Path ..\Application\src\ -Filter *.al -Recurse

    foreach ($file in $fileList) {
        try {            
            AddFileToArray $file
        }
        catch { 
            Write-Host 'Error when handling file: ' $file.FullName
            throw $_
        }    
            
    }
    GeneratePermissionSetFile
    Write-Host 'Done Generating Permission File.'
}

runScript