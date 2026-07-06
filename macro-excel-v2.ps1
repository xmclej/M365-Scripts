# Excel Macro and Office Hardening Audit
# Output file: Excel_Security_Audit_yyyyMMdd_HHmmss.txt

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFile = "Excel_Security_Audit_$Timestamp.txt"

$Checks = @(
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security';Name='AccessVBOM';Expected=0}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\Trusted Locations';Name='AllowNetworkLocations';Expected=0}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\Trusted Locations';Name='DisableTrustedLocations';Expected=1}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\Trusted Documents';Name='DisableTrustedDocuments';Expected=1}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\Trusted Documents';Name='DisableTrustedDocumentsOnNetwork';Expected=1}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security';Name='VBAWarnings';Expected=1}

    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security';Name='blockcontentexecutionfrominternet';Expected=1}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security';Name='ExtensionHardening';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security';Name='NotBPromptUnsignedAddin';Expected=1}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security';Name='RequireAddinSig';Expected=1}

    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileValidation';Name='EnableOnLoad';Expected=1}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileValidation';Name='OpenInProtectedView';Expected=0}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileValidation';Name='DisableEditFromPV';Expected=1}

    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\ProtectedView';Name='DisableInternetFilesInPV';Expected=0}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\ProtectedView';Name='DisableUnsafeLocationsInPV';Expected=0}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\ProtectedView';Name='DisableAttachmentsInPV';Expected=0}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\ProtectedView';Name='EnableDatabaseFileProtectedView';Expected=1}

    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\External Content';Name='EnableBlockUnsecureQueryFiles';Expected=1}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\External Content';Name='DisableDDEServerLaunch';Expected=1}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\External Content';Name='DisableDDEServerLookup';Expected=1}

    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='DBaseFiles';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='DifAndSylkFiles';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL2Macros';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL2Worksheets';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL3Macros';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL3Worksheets';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL4Macros';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL4Workbooks';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL4Worksheets';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL95Workbooks';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL9597WorkbooksAndTemplates';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='XL97WorkbooksAndTemplates';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='HtmlAndXmlssFiles';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock';Name='OpenInProtectedView';Expected=0}

    @{Path='HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Security';Name='MacroRuntimeScanScope';Expected=2}
    @{Path='HKCU:\Software\Policies\Microsoft\Office\Common\Security';Name='DisableAllActiveX';Expected=1}
)

$Results = foreach ($Item in $Checks) {

    $CurrentValue = $null
    $Status = "NOT FOUND"

    if (Test-Path $Item.Path) {

        try {
            $RegData = Get-ItemProperty -Path $Item.Path -Name $Item.Name -ErrorAction Stop
            $CurrentValue = $RegData.($Item.Name)

            if ($CurrentValue -eq $Item.Expected) {
                $Status = "PASS"
            }
            else {
                $Status = "FAIL"
            }
        }
        catch {
            $CurrentValue = "<Value Missing>"
            $Status = "NOT FOUND"
        }
    }

    [PSCustomObject]@{
        RegistryPath = $Item.Path
        ValueName    = $Item.Name
        CurrentValue = $CurrentValue
        Expected     = $Item.Expected
        Status       = $Status
    }
}

# Write detailed results
"Excel Security Configuration Audit" | Out-File $OutputFile
"Generated: $(Get-Date)" | Out-File $OutputFile -Append
"" | Out-File $OutputFile -Append

$Results |
    Sort-Object RegistryPath, ValueName |
    Format-Table -AutoSize |
    Out-String |
    Out-File $OutputFile -Append

# Macro-relevant summary
$MacroCritical = @(
    'VBAWarnings',
    'blockcontentexecutionfrominternet',
    'DisableTrustedDocuments',
    'DisableTrustedDocumentsOnNetwork',
    'DisableTrustedLocations',
    'AllowNetworkLocations',
    'AccessVBOM',
    'RequireAddinSig',
    'MacroRuntimeScanScope'
)

$Summary = $Results | Where-Object {
    $_.ValueName -in $MacroCritical
}

"" | Out-File $OutputFile -Append
"==================================================================" | Out-File $OutputFile -Append
"EXCEL MACRO EXECUTION IMPACT SUMMARY" | Out-File $OutputFile -Append
"==================================================================" | Out-File $OutputFile -Append

$Summary |
    Format-Table ValueName,CurrentValue,Expected,Status -AutoSize |
    Out-String |
    Out-File $OutputFile -Append

"" | Out-File $OutputFile -Append
"Interpretation of Key Macro Controls:" | Out-File $OutputFile -Append
"--------------------------------------------------------------" | Out-File $OutputFile -Append
"VBAWarnings" | Out-File $OutputFile -Append
"  1 = Disable VBA macros with notification." | Out-File $OutputFile -Append
"blockcontentexecutionfrominternet" | Out-File $OutputFile -Append
"  1 = Block macros in files carrying Mark-of-the-Web." | Out-File $OutputFile -Append
"DisableTrustedDocuments" | Out-File $OutputFile -Append
"  1 = Users cannot trust documents to bypass macro restrictions." | Out-File $OutputFile -Append
"DisableTrustedDocumentsOnNetwork" | Out-File $OutputFile -Append
"  1 = Network documents cannot become trusted." | Out-File $OutputFile -Append
"DisableTrustedLocations" | Out-File $OutputFile -Append
"  1 = Trusted Locations feature disabled." | Out-File $OutputFile -Append
"AllowNetworkLocations" | Out-File $OutputFile -Append
"  0 = Network paths cannot be used as trusted locations." | Out-File $OutputFile -Append
"AccessVBOM" | Out-File $OutputFile -Append
"  0 = VBA projects cannot access VBA object model." | Out-File $OutputFile -Append
"RequireAddinSig" | Out-File $OutputFile -Append
"  1 = Excel add-ins must be signed." | Out-File $OutputFile -Append
"MacroRuntimeScanScope" | Out-File $OutputFile -Append
"  2 = Runtime scanning of macros enabled." | Out-File $OutputFile -Append

Write-Host ""
Write-Host "Audit complete."
Write-Host "Results written to:"
Write-Host (Resolve-Path $OutputFile)