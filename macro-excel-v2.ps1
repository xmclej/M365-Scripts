# Excel Macro and Office Hardening Audit
# Output: Excel_Security_Audit_yyyyMMdd_HHmmss.csv


$FirstName = Read-Host "Enter your first name"

# Remove invalid filename characters and spaces
$FirstName = ($FirstName -replace '[\\/:*?"<>| ]','')

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFile = "${FirstName}_Excel_Security_Audit_$Timestamp.csv"
$AuditTime = Get-Date

# Registry path groups

$ExcelSecurityPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security'
    'HKCU:\Software\Microsoft\Office\16.0\Excel\Security'
)

$TrustedLocationPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\Trusted Locations'
    'HKCU:\Software\Microsoft\Office\16.0\Excel\Security\Trusted Locations'
)

$TrustedDocumentPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\Trusted Documents'
    'HKCU:\Software\Microsoft\Office\16.0\Excel\Security\Trusted Documents'
)

$ProtectedViewPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\ProtectedView'
    'HKCU:\Software\Microsoft\Office\16.0\Excel\Security\ProtectedView'
)

$ExternalContentPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\External Content'
    'HKCU:\Software\Microsoft\Office\16.0\Excel\Security\External Content'
)

$FileValidationPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileValidation'
    'HKCU:\Software\Microsoft\Office\16.0\Excel\Security\FileValidation'
)

$FileBlockPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security\FileBlock'
    'HKCU:\Software\Microsoft\Office\16.0\Excel\Security\FileBlock'
)

$CommonSecurityPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Security'
    'HKCU:\Software\Microsoft\Office\16.0\Common\Security'
)

$OfficeCommonSecurityPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\Common\Security'
    'HKCU:\Software\Microsoft\Office\Common\Security'
    'HKCU:\Software\Microsoft\Office\16.0\Common\Security'
)

$IdentityPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Identity'
    'HKCU:\Software\Microsoft\Office\16.0\Common\Identity'
)

$TrustedCatalogPaths = @(
    'HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Security\Trusted Catalogs'
    'HKCU:\Software\Microsoft\Office\16.0\Common\Security\Trusted Catalogs'
)

# ------------------------------
# Add Checks here
# ------------------------------
$Checks = @(

    # VBA / Macro Security

    @{Paths=$ExcelSecurityPaths;Name='AccessVBOM';Expected=0}
    @{Paths=$ExcelSecurityPaths;Name='VBAWarnings';Expected=1}
    @{Paths=$ExcelSecurityPaths;Name='blockcontentexecutionfrominternet';Expected=1}
    @{Paths=$ExcelSecurityPaths;Name='ExtensionHardening';Expected=2}
    @{Paths=$ExcelSecurityPaths;Name='RequireAddinSig';Expected=1}
    @{Paths=$ExcelSecurityPaths;Name='NotBPromptUnsignedAddin';Expected=1}
    @{Paths=$ExcelSecurityPaths;Name='XLMMacros';Expected=1}

    # Trusted Locations

    @{Paths=$TrustedLocationPaths;Name='AllowNetworkLocations';Expected=0}
    @{Paths=$TrustedLocationPaths;Name='DisableTrustedLocations';Expected=1}

    # Trusted Documents

    @{Paths=$TrustedDocumentPaths;Name='DisableTrustedDocuments';Expected=1}
    @{Paths=$TrustedDocumentPaths;Name='DisableTrustedDocumentsOnNetwork';Expected=1}

    # File Validation

    @{Paths=$FileValidationPaths;Name='EnableOnLoad';Expected=1}
    @{Paths=$FileValidationPaths;Name='OpenInProtectedView';Expected=0}
    @{Paths=$FileValidationPaths;Name='DisableEditFromPV';Expected=1}

    # Protected View

    @{Paths=$ProtectedViewPaths;Name='DisableInternetFilesInPV';Expected=0}
    @{Paths=$ProtectedViewPaths;Name='DisableUnsafeLocationsInPV';Expected=0}
    @{Paths=$ProtectedViewPaths;Name='DisableAttachmentsInPV';Expected=0}
    @{Paths=$ProtectedViewPaths;Name='EnableDatabaseFileProtectedView';Expected=1}

    # External Content

    @{Paths=$ExternalContentPaths;Name='EnableBlockUnsecureQueryFiles';Expected=1}
    @{Paths=$ExternalContentPaths;Name='DisableDDEServerLaunch';Expected=1}
    @{Paths=$ExternalContentPaths;Name='DisableDDEServerLookup';Expected=1}
    @{Paths=$ExternalContentPaths;Name='WorkbookLinkWarnings';Expected=2}
    @{Paths=$ExternalContentPaths;Name='DataConnectionWarnings';Expected=2}

    # Common Security

    @{Paths=$CommonSecurityPaths;Name='MacroRuntimeScanScope';Expected=2}
    @{Paths=$CommonSecurityPaths;Name='EnableAmsiProtection';Expected=1}
    @{Paths=$CommonSecurityPaths;Name='DisableAllAddins';Expected=0}
    @{Paths=$CommonSecurityPaths;Name='PackagerPrompt';Expected=2}
    @{Paths=$CommonSecurityPaths;Name='ActivationFilterOverride';Expected=0}
    @{Paths=$CommonSecurityPaths;Name='AllowUserToEnterApplicationGuard';Expected=0}

    # ActiveX

    @{Paths=$OfficeCommonSecurityPaths;Name='DisableAllActiveX';Expected=1}
    @{Paths=$OfficeCommonSecurityPaths;Name='UFIControls';Expected=1}

    # Identity

    @{Paths=$IdentityPaths;Name='DisableADALatopWAMOverride';Expected=1}

    # Trusted Catalogs

    @{Paths=$TrustedCatalogPaths;Name='RequireCatalogUpdate';Expected=1}

    # File Block

    @{Paths=$FileBlockPaths;Name='DBaseFiles';Expected=2}
    @{Paths=$FileBlockPaths;Name='DifAndSylkFiles';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL2Macros';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL2Worksheets';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL3Macros';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL3Worksheets';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL4Macros';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL4Workbooks';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL4Worksheets';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL95Workbooks';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL9597WorkbooksAndTemplates';Expected=2}
    @{Paths=$FileBlockPaths;Name='XL97WorkbooksAndTemplates';Expected=2}
    @{Paths=$FileBlockPaths;Name='HtmlAndXmlssFiles';Expected=2}
    @{Paths=$FileBlockPaths;Name='OpenInProtectedView';Expected=0}

)

# ------------------------------
# PERFORM CHECKS
# ------------------------------
$Results = foreach ($Item in $Checks) {

    $CurrentValue = "<Path Missing>"
    $Status = "PATH NOT FOUND"
    $FoundPath = ""
    $SearchedPaths = ""

    # Support both new Paths=@() format and old Path='' format
    if ($Item.ContainsKey('Paths')) {
        $PathsToCheck = $Item.Paths
    }
    else {
        $PathsToCheck = @($Item.Path)
    }

    $SearchedPaths = $PathsToCheck -join "; "

    foreach ($Path in $PathsToCheck) {

        if (Test-Path $Path) {

            try {
                $RegData = Get-ItemProperty -Path $Path -Name $Item.Name -ErrorAction Stop

                $CurrentValue = $RegData.($Item.Name)
                $FoundPath = $Path

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

                # Stop searching once we find a value
                break
            }
            catch {
                # Value not present at this path
                if ($Status -eq "PATH NOT FOUND") {
                    $CurrentValue = "<Value Missing>"
                    $Status = "VALUE NOT FOUND"
                }
            }
        }
    }

    # Determine policy source
    $PolicySource = switch -Wildcard ($FoundPath) {
        '*\Policies\*' {
            'Policy Registry'
        }
        '*\Microsoft\Office\16.0\*' {
            'Office Registry'
        }
        default {
            ''
        }
    }

    [PSCustomObject]@{
        AuditTime          = $AuditTime
        RegistryPath       = if ($FoundPath) { $FoundPath } else { "<Not Found>" }
        SearchedPaths      = $SearchedPaths
        ValueName          = $Item.Name
        CurrentValue       = $CurrentValue
        Expected           = $Item.Expected
        Status             = $Status
        PolicySource       = $PolicySource

        MacroImpact = switch ($Item.Name) {
            'VBAWarnings' { 'HIGH' }
            'blockcontentexecutionfrominternet' { 'HIGH' }
            'DisableTrustedDocuments' { 'HIGH' }
            'DisableTrustedDocumentsOnNetwork' { 'HIGH' }
            'DisableTrustedLocations' { 'HIGH' }
            'AllowNetworkLocations' { 'HIGH' }
            'RequireAddinSig' { 'HIGH' }
            'EnableAmsiProtection' { 'HIGH' }
            'XLMMacros' { 'HIGH' }

            'AccessVBOM' { 'MEDIUM' }
            'DisableAllActiveX' { 'MEDIUM' }
            'MacroRuntimeScanScope' { 'MEDIUM' }
            'WorkbookLinkWarnings' { 'MEDIUM' }
            'DataConnectionWarnings' { 'MEDIUM' }
            'PackagerPrompt' { 'MEDIUM' }
            'UFIControls' { 'MEDIUM' }

            default { 'LOW' }
        }

        MacroExecutionRisk = switch ($Item.Name) {
            'VBAWarnings' { 'Can block VBA execution' }
            'blockcontentexecutionfrominternet' { 'Blocks MOTW files' }
            'DisableTrustedLocations' { 'Prevents trusted shares' }
            'DisableTrustedDocuments' { 'Prevents document trust' }
            'RequireAddinSig' { 'Unsigned add-ins blocked' }
            'DisableAllActiveX' { 'ActiveX controls blocked' }

            'EnableAmsiProtection' { 'AMSI scanning enabled' }
            'XLMMacros' { 'Excel 4.0 macros blocked' }
            'WorkbookLinkWarnings' { 'External links controlled' }
            'DataConnectionWarnings' { 'External data connections controlled' }
            'PackagerPrompt' { 'OLE package activation restricted' }
            'UFIControls' { 'Unsafe ActiveX initialization blocked' }

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

            'EnableAmsiProtection' { 'Scans VBA with Defender AMSI' }
            'XLMMacros' { 'Blocks Excel 4.0 macro execution' }
            'WorkbookLinkWarnings' { 'Controls workbook link behaviour' }
            'DataConnectionWarnings' { 'Controls external data connections' }
            'PackagerPrompt' { 'Restricts embedded package activation' }
            'UFIControls' { 'Controls unsafe ActiveX initialization' }

            default { '' }
        }
    }
}

# ------------------------------
# EXPORT DETAILED RESULTS
# ------------------------------

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

Write-Host "Total Checks: $($Results.Count)"
Write-Host ""

$Results |
    Group-Object Status |
    Sort-Object Name |
    Select-Object Name, Count |
    Format-Table -AutoSize