# Excel Macro and Office Hardening Audit
# Output: Excel_Security_Audit_yyyyMMdd_HHmmss.csv

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFile = "Excel_Security_Audit_$Timestamp.csv"
$AuditTime = Get-Date

# ------------------------------
# Add Checks here
# ------------------------------
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

# ------------------------------
# PERFORM CHECKS
# ------------------------------
$Results = foreach ($Item in $Checks) {

    $CurrentValue = "<Path Missing>"
    $Status = "PATH NOT FOUND"

    if (Test-Path $Item.Path) {

        try {
            $RegData = Get-ItemProperty -Path $Item.Path -Name $Item.Name -ErrorAction Stop
            $CurrentValue = $RegData.($Item.Name)

            if ($null -eq $CurrentValue) {
                $CurrentValue = "<Null>"
                $Status = "VALUE EMPTY"
            }
            elseif ($CurrentValue -eq $Item.Expected) {
                $Status = "PASS"
            }
            else {
                $Status = "FAIL"
            }
        }
        catch {
            $CurrentValue = "<Value Missing>"
            $Status = "VALUE NOT FOUND"
        }
    }

    [PSCustomObject]@{
        AuditTime    = $AuditTime
        RegistryPath = $Item.Path
        ValueName    = $Item.Name
        CurrentValue = $CurrentValue
        Expected     = $Item.Expected
        Status       = $Status

        MacroImpact = switch ($Item.Name) {
            'VBAWarnings' { 'HIGH' }
            'blockcontentexecutionfrominternet' { 'HIGH' }
            'DisableTrustedDocuments' { 'HIGH' }
            'DisableTrustedDocumentsOnNetwork' { 'HIGH' }
            'DisableTrustedLocations' { 'HIGH' }
            'AllowNetworkLocations' { 'HIGH' }
            'RequireAddinSig' { 'HIGH' }
            'AccessVBOM' { 'MEDIUM' }
            'DisableAllActiveX' { 'MEDIUM' }
            'MacroRuntimeScanScope' { 'MEDIUM' }
            default { 'LOW' }
        }
        MacroExecutionRisk = switch ($Item.Name) {
            'VBAWarnings' { 'Can block VBA execution' }
            'blockcontentexecutionfrominternet' { 'Blocks MOTW files' }
            'DisableTrustedLocations' { 'Prevents trusted shares' }
            'DisableTrustedDocuments' { 'Prevents document trust' }
            'RequireAddinSig' { 'Unsigned add-ins blocked' }
            'DisableAllActiveX' { 'ActiveX controls blocked' }
            default { '' }
        }
        PolicyEffect = switch ($Item.Name) {
            'VBAWarnings' { 'Controls VBA execution' }
            'blockcontentexecutionfrominternet' { 'Blocks macros from internet files' }
            'DisableTrustedDocuments' { 'Disables document trust' }
            'DisableTrustedDocumentsOnNetwork' { 'Disables trust on network files' }
            'DisableTrustedLocations' { 'Disables trusted locations' }
            'AllowNetworkLocations' { 'Controls network trusted locations' }
            'RequireAddinSig' { 'Requires signed add-ins' }
            'DisableAllActiveX' { 'Blocks ActiveX controls' }
            'MacroRuntimeScanScope' { 'Controls runtime AV scanning of macros' }
            default { '' }
        }
    }
}

# Export detailed results
# Sort-Object RegistryPath, ValueName |
$Results |
    Sort-Object @{Expression='MacroImpact';Descending=$true}, RegistryPath, ValueName |
    Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Audit complete."
Write-Host "Results written to:"
Write-Host (Resolve-Path $OutputFile)

Write-Host ""
Write-Host "Status Summary"
Write-Host "--------------"

$Results |
    Group-Object Status |
    Sort-Object Name |
    Select-Object Name, Count |
    Format-Table -AutoSize