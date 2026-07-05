Write-Host "===================================================="
Write-Host "Excel Macro / ActiveX Diagnostic Script"
Write-Host "===================================================="
Write-Host ""

function Get-RegKey {
    param(
        [string]$Path,
        [string]$Title
    )

    Write-Host ""
    Write-Host "----------------------------------------------------"
    Write-Host $Title
    Write-Host "----------------------------------------------------"

    if (Test-Path $Path) {
        Get-ItemProperty -Path $Path |
            Format-List *
    }
    else {
        Write-Host "NOT FOUND"
    }
}

Write-Host "User: $env:USERNAME"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host ""

# -----------------------------------------------------
# Office Policy Settings
# -----------------------------------------------------

Get-RegKey `
    -Path "HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security" `
    -Title "Excel Security Policies"

Get-RegKey `
    -Path "HKCU:\Software\Policies\Microsoft\Office\Common\Security" `
    -Title "Office Common Security Policies"

Get-RegKey `
    -Path "HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Security" `
    -Title "Office 16 Common Security Policies"

    reg query "HKCU\Software\Microsoft\Office\16.0\Excel\Security" /v BlockContentExecutionFromInternet
`
# -----------------------------------------------------
# User Excel Security Settings
# -----------------------------------------------------

Get-RegKey `
    -Path "HKCU:\Software\Microsoft\Office\16.0\Excel\Security" `
    -Title "Excel User Security Settings"

Get-RegKey `
    -Path "HKCU:\Software\Microsoft\Office\Common\Security" `
    -Title "Office User Security Settings"

Get-RegKey `
    -Path "HKCU:\Software\Microsoft\Office\16.0\Common\Security" `
    -Title "Office 16 User Security Settings"

    Write-Host ""
    Write-Host "----------------------------------------------------"
    Write-Host "Important Excel Security Values"
    Write-Host "----------------------------------------------------"

    $excelSec = "HKCU:\Software\Microsoft\Office\16.0\Excel\Security"

    if (Test-Path $excelSec) {
        $props = Get-ItemProperty $excelSec

        Write-Host "VBAWarnings:" $props.VBAWarnings

        if ($null -ne $props.BlockContentExecutionFromInternet) {
            Write-Host "BlockContentExecutionFromInternet:" $props.BlockContentExecutionFromInternet
        }
    }
# -----------------------------------------------------
# Trusted Locations
# -----------------------------------------------------

Write-Host ""
Write-Host "----------------------------------------------------"
Write-Host "Excel Trusted Locations"
Write-Host "----------------------------------------------------"

$trustedLocationRoot =
    "HKCU:\Software\Microsoft\Office\16.0\Excel\Security\Trusted Locations"

if (Test-Path $trustedLocationRoot)
{
    Get-ChildItem $trustedLocationRoot | ForEach-Object {
        Write-Host ""
        Write-Host $_.PSChildName
        Get-ItemProperty $_.PSPath |
            Select-Object Path,Description,AllowSubFolders |
            Format-List
    }
}
else
{
    Write-Host "No Trusted Locations found."
}

# -----------------------------------------------------
# Office Cloud Policy
# -----------------------------------------------------

Get-RegKey `
    -Path "HKCU:\Software\Policies\Microsoft\Cloud\Office" `
    -Title "Office Cloud Policy"

# -----------------------------------------------------
# SharePoint Zone Mapping
# -----------------------------------------------------

Write-Host ""
Write-Host "----------------------------------------------------"
Write-Host "ZoneMap Domains"
Write-Host "----------------------------------------------------"

$zoneMap =
"HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"

if (Test-Path $zoneMap)
{
    Get-ChildItem $zoneMap -Recurse |
    ForEach-Object {

        try {
            $item = Get-ItemProperty $_.PSPath

            if (
                $_.PSChildName -match "sharepoint" -or
                $_.PSChildName -match "office" -or
                $_.PSChildName -match "microsoft"
            )
            {
                Write-Host ""
                Write-Host $_.Name
                $item | Format-List
            }
        }
        catch {}
    }
}    
# # -----------------------------------------------------
# # SharePoint / Internet Zone Assignments
# # -----------------------------------------------------

# Write-Host ""
# Write-Host "----------------------------------------------------"
# Write-Host "Internet Explorer Zone Assignments"
# Write-Host "----------------------------------------------------"

# $zoneMap = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap"

# if (Test-Path $zoneMap)
# {
#     Get-ChildItem $zoneMap -Recurse |
#         ForEach-Object {
#             try {
#                 Get-ItemProperty $_.PSPath |
#                     Format-List
#             }
#             catch {}
#         }
# }

# -----------------------------------------------------
# Key Registry Values
# -----------------------------------------------------

Write-Host ""
Write-Host "----------------------------------------------------"
Write-Host "Important Values Summary"
Write-Host "----------------------------------------------------"

$checks = @(
    @{
        Name = "Policy VBAWarnings"
        Path = "HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security"
        Value = "VBAWarnings"
    },
    @{
        Name = "Policy BlockContentExecutionFromInternet"
        Path = "HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security"
        Value = "BlockContentExecutionFromInternet"
    },
    @{
        Name = "Local VBAWarnings"
        Path = "HKCU:\Software\Microsoft\Office\16.0\Excel\Security"
        Value = "VBAWarnings"
    },
    @{
        Name = "DisableAllActiveX"
        Path = "HKCU:\Software\Microsoft\Office\Common\Security"
        Value = "DisableAllActiveX"
    }
)

# $checks = @(
#     @{
#         Name = "DisableAllActiveX"
#         Path = "HKCU:\Software\Microsoft\Office\Common\Security"
#         Value = "DisableAllActiveX"
#     },
#     @{
#         Name = "Excel VBAWarnings"
#         Path = "HKCU:\Software\Microsoft\Office\16.0\Excel\Security"
#         Value = "VBAWarnings"
#     }
# )

foreach ($check in $checks)
{
    try
    {
        $value =
            (Get-ItemProperty -Path $check.Path `
            -ErrorAction Stop).($check.Value)

        Write-Host "$($check.Name): $value"
    }
    catch
    {
        Write-Host "$($check.Name): Not Found"
    }
}

# -----------------------------------------------------
# Office Version
# -----------------------------------------------------

Write-Host ""
Write-Host "----------------------------------------------------"
Write-Host "Office Version"
Write-Host "----------------------------------------------------"

$officePath =
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"

if (Test-Path $officePath)
{
    Get-ItemProperty $officePath |
        Select-Object VersionToReport,
                      ProductReleaseIds,
                      UpdateChannel |
        Format-List
}
else
{
    Write-Host "Office Click-To-Run information not found."
}

# -----------------------------------------------------
# Mark of the Web (MOTW) Check
# -----------------------------------------------------

Write-Host ""
Write-Host "----------------------------------------------------"
Write-Host "Mark of the Web (MOTW) Check"
Write-Host "----------------------------------------------------"

$filePath = Read-Host "Enter path to XLSM file (or press Enter to skip)"

if ((null -ne $filePath) -and ($filePath -ne ""))
{
    if (Test-Path $filePath)
    {
        try
        {
            $streams = Get-Item -Path $filePath -Stream * -ErrorAction Stop

            $zoneStream = $streams | Where-Object {
                $_.Stream -eq "Zone.Identifier"
            }

            if ($zoneStream)
            {
                Write-Host ""
                Write-Host "MOTW DETECTED"
                Write-Host "The file contains a Zone.Identifier alternate data stream."
                Write-Host ""

                Write-Host "Zone.Identifier Contents:"
                Write-Host "------------------------"

                Get-Content "$filePath`:Zone.Identifier"
            }
            else
            {
                Write-Host ""
                Write-Host "No Mark-of-the-Web detected."
            }
        }
        catch
        {
            Write-Host "Unable to check alternate data streams."
            Write-Host $_.Exception.Message
        }
    }
    else
    {
        Write-Host "File not found."
    }
}
else
{
    Write-Host "MOTW check skipped."
}
# -----------------------------------------------------
# Interpretation Guide
# -----------------------------------------------------

Write-Host ""
Write-Host "===================================================="
Write-Host "INTERPRETATION GUIDE"
Write-Host "===================================================="
Write-Host ""
Write-Host "VBAWarnings"
Write-Host " 1 = Enable VBA macros"
Write-Host " 2 = Disable VBA macros with notification"
Write-Host " 3 = Disable all except digitally signed"
Write-Host " 4 = Disable all without notification"
Write-Host ""
Write-Host "DisableAllActiveX"
Write-Host " 0 = Not blocked"
Write-Host " 1 = Disable all controls without notification"
Write-Host ""
Write-Host "blockcontentexecutionfrominternet"
Write-Host " 1 = Block macros from Internet/SharePoint"
Write-Host " 0 = Not blocked"
Write-Host ""