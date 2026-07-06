$LogFile = "Macro-Diagnostics-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

if (Test-Path $LogFile) {
    Remove-Item $LogFile -Force
}

# -----------------------------------------------------
# Functions
# -----------------------------------------------------
function Write-Log {
    param(
        [string]$Message
    )

    $Message | Out-File -FilePath $LogFile -Append -Encoding UTF8
}
function Get-RegKey {
    param(
        [string]$Path,
        [string]$Title
    )
    Write-Log ""
    Write-Log "----------------------------------------------------"
    Write-Log $Title
    Write-Log "----------------------------------------------------"
    if (Test-Path $Path) {
        Get-ItemProperty -Path $Path |
            Format-List *
    }
    else {
        Write-Log "NOT FOUND"
    }
}

Write-Log "===================================================="
Write-Log "Excel Macro / ActiveX Diagnostic Script"
Write-Log "===================================================="
Write-Log ""
Write-Log "User: $env:USERNAME"
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log ""

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

    Write-Log ""
    Write-Log "----------------------------------------------------"
    Write-Log "Important Excel Security Values"
    Write-Log "----------------------------------------------------"

    $excelSec = "HKCU:\Software\Microsoft\Office\16.0\Excel\Security"

    if (Test-Path $excelSec) {
        $props = Get-ItemProperty $excelSec

        Write-Log "VBAWarnings:" $props.VBAWarnings

        if ($null -ne $props.BlockContentExecutionFromInternet) {
            Write-Log "BlockContentExecutionFromInternet:" $props.BlockContentExecutionFromInternet
        }
    }
# -----------------------------------------------------
# Trusted Locations
# -----------------------------------------------------

Write-Log ""
Write-Log "----------------------------------------------------"
Write-Log "Excel Trusted Locations"
Write-Log "----------------------------------------------------"

$trustedLocationRoot =
    "HKCU:\Software\Microsoft\Office\16.0\Excel\Security\Trusted Locations"

if (Test-Path $trustedLocationRoot)
{
    Get-ChildItem $trustedLocationRoot | ForEach-Object {
        Write-Log ""
        Write-Log $_.PSChildName
        Get-ItemProperty $_.PSPath |
            Select-Object Path,Description,AllowSubFolders |
            Format-List
    }
}
else
{
    Write-Log "No Trusted Locations found."
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

Write-Log ""
Write-Log "----------------------------------------------------"
Write-Log "ZoneMap Domains"
Write-Log "----------------------------------------------------"

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
                Write-Log ""
                Write-Log $_.Name
                $item | Format-List
            }
        }
        catch {}
    }
}    
# # -----------------------------------------------------
# # SharePoint / Internet Zone Assignments
# # -----------------------------------------------------

# Write-Log ""
# Write-Log "----------------------------------------------------"
# Write-Log "Internet Explorer Zone Assignments"
# Write-Log "----------------------------------------------------"

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

Write-Log ""
Write-Log "----------------------------------------------------"
Write-Log "Important Values Summary"
Write-Log "----------------------------------------------------"

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

        Write-Log "$($check.Name): $value"
    }
    catch
    {
        Write-Log "$($check.Name): Not Found"
    }
}

# -----------------------------------------------------
# Office Version
# -----------------------------------------------------

Write-Log ""
Write-Log "----------------------------------------------------"
Write-Log "Office Version"
Write-Log "----------------------------------------------------"

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
    Write-Log "Office Click-To-Run information not found."
}

# -----------------------------------------------------
# Mark of the Web (MOTW) Check
# -----------------------------------------------------

Write-Log ""
Write-Log "----------------------------------------------------"
Write-Log "Mark of the Web (MOTW) Check"
Write-Log "----------------------------------------------------"

$filePath = Read-Host "Enter path to XLSM file (or press Enter to skip)"

if ($filePath)
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
                Write-Log ""
                Write-Log "MOTW DETECTED"
                Write-Log "The file contains a Zone.Identifier alternate data stream."
                Write-Log ""

                Write-Log "Zone.Identifier Contents:"
                Write-Log "------------------------"

                Get-Content "$filePath`:Zone.Identifier"
            }
            else
            {
                Write-Log ""
                Write-Log "No Mark-of-the-Web detected."
            }
        }
        catch
        {
            Write-Log "Unable to check alternate data streams."
            Write-Log $_.Exception.Message
        }
    }
    else
    {
        Write-Log "File not found."
    }
}
else
{
    Write-Log "MOTW check skipped."
}
# -----------------------------------------------------
# Interpretation Guide
# -----------------------------------------------------

Write-Log ""
Write-Log "===================================================="
Write-Log "INTERPRETATION GUIDE"
Write-Log "===================================================="
Write-Log ""
Write-Log "VBAWarnings"
Write-Log " 1 = Enable VBA macros"
Write-Log " 2 = Disable VBA macros with notification"
Write-Log " 3 = Disable all except digitally signed"
Write-Log " 4 = Disable all without notification"
Write-Log ""
Write-Log "DisableAllActiveX"
Write-Log " 0 = Not blocked"
Write-Log " 1 = Disable all controls without notification"
Write-Log ""
Write-Log "blockcontentexecutionfrominternet"
Write-Log " 1 = Block macros from Internet/SharePoint"
Write-Log " 0 = Not blocked"
Write-Log ""

Write-Log ""
Write-Log "Diagnostic completed."

Write-Host "Results saved to:"
Write-Host $LogFile