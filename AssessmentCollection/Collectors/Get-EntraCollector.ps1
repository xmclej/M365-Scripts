function Get-EntraCollector {

    param(
        [int]$DaysBack = 30
    )
# E8-MFA-001 Admin MFA
# E8-MFA-002 Legacy Authentication
# E8-MFA-003 Strong Authentication Methods
# E8-MFA-004 CA Policy Applies To Admins
# E8-MFA-005 MFA Registration Coverage

# BP-ID-001 Security Defaults
# BP-ID-002 Global Admin Count
# BP-ID-003 Break Glass Accounts
# BP-CA-001 Report Only Policies
# BP-CA-002 Named Locations Configured

    . "$PSScriptRoot\Entra\Get-EntraConditionalAccess.ps1"
    . "$PSScriptRoot\Entra\Get-EntraMFARegistration.ps1"
    . "$PSScriptRoot\Entra\Get-EntraLegacyAuthentication.ps1"
    . "$PSScriptRoot\Entra\Get-EntraAuthenticationMethods.ps1"


    . "$PSScriptRoot\Entra\Get-EntraSecurityDefaults.ps1"
    . "$PSScriptRoot\Entra\Get-EntraNamedLocations.ps1"    
    . "$PSScriptRoot\Entra\Get-EntraDirectoryRoles.ps1"
    . "$PSScriptRoot\Entra\Get-EntraBreakGlassAccounts.ps1"


    # -------------------------------------------------------------------------
    # Main code starts here
    # ------------------------------------------------------------------------

    $CollectorErrors = [System.Collections.Generic.List[object]]::new()
    $Component = "EntraCollector"
    $Section = "STARTUP"

    Write-AssessmentLog `
        -Level "INFO" `
        -Component $Component `
        -Section $Section `
        -Message "Collector started" `

    $ErrorActionPreference = "Stop"

    # -------------------------------------------------------------------------
    # Verify Graph Connection
    # -------------------------------------------------------------------------

    try {
        $context = Get-MgContext
        if (-not $context) {
            throw "No Graph connection detected."
        }
    }
    catch {
        throw "Get-EntraCollector requires an existing Microsoft Graph connection."
    }

    # -------------------------------------------------------------------------
    # Conditional Access
    # -------------------------------------------------------------------------
    $Section = "CONDITIONAL-ACCESS"
    $caExport   = @()

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Starting Conditional Access collection" `

        $caExport = Get-EntraConditionalAccess

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Retrieved $($caPolicies.Count) policies" `

    }
    catch {
        $CollectorErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
    }

    # -------------------------------------------------------------------------
    # MFA Registration
    # -------------------------------------------------------------------------
    $Section = "MFA-REGISTRATION"
    $mfaExport = @()

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Collecting MFA registration"

        $mfaExport = Get-EntraMFARegistration

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Retrieved $($mfaExport.Count) mfa registration records"

    }
    catch {

        $CollectorErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
    }

    # -------------------------------------------------------------------------
    # Legacy Authentication
    # -------------------------------------------------------------------------
    $Section = "LEGACY-AUTH"
    $legacyExport = @()

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Collecting legacy authentication sign-ins"

        $legacyExport = Get-EntraLegacyAuthentication `
            -DaysBack $DaysBack

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Retrieved $($legacyExport.Count) legacy authentication sign-ins"

    }
    catch {

        $CollectorErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
    }
    # -------------------------------------------------------------------------
    # Authentication Methods Policy
    # -------------------------------------------------------------------------
    $Section = "AuthenticationMethods"
    $AuthenticationMethods = $null

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Collecting Authentication Methods Policy"

        $AuthenticationMethods = Get-EntraAuthenticationMethods

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Authentication Methods Policy collected"

    }
    catch {

        $CollectorErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
    }

    # -------------------------------------------------------------------------
    # Security Defaults - Best Practice
    # -------------------------------------------------------------------------
    $Section = "SecurityDefaults"
    $SecurityDefaults = $null

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Collecting Authentication Methods Policy"

        $SecurityDefaults = Get-EntraSecurityDefaults

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Authentication Methods Policy collected"

    }
    catch {

        $CollectorErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
    }

    # -------------------------------------------------------------------------
    # Named Locations - Best Practice
    # -------------------------------------------------------------------------
    $Section = "NamedLocations"
    $NamedLocations = $null

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Collecting named locations"

        $NamedLocations = Get-EntraNamedLocations

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Named locations collected"

    }
    catch {

        $CollectorErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
    }

    # -------------------------------------------------------------------------
    # Directory Roles - Best Practice
    # -------------------------------------------------------------------------
    $Section = "NamedLocations"
    $DirectoryRoles = $null

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Collecting directory roles"

        $DirectoryRoles = Get-EntraDirectoryRoles

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Directory roles collected"

    }
    catch {

        $CollectorErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
    }

    # -------------------------------------------------------------------------
    # Break Glass Accounts - Best Practice
    # -------------------------------------------------------------------------
    $Section = "BreakGlassAccounts"
    $DirectoryRoles = $null

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Collecting break glass accounts"

        $BreakGlassAccounts = Get-EntraBreakGlassAccounts

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Break glass accounts collected"

    }
    catch {

        $CollectorErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
    }

    # # -------------------------------------------------------------------------
    # # Findings
    # # -------------------------------------------------------------------------
    # $Section = "FINDINGS"
    # $findings = @()

    # $reportOnlyCount = (
    #     $caPolicies |
    #     Where-Object State -eq "enabledForReportingButNotEnforced"
    # ).Count

    # if ($reportOnlyCount -gt 0) {

    #     $findings += [PSCustomObject]@{
    #         Category = "Conditional Access"
    #         Setting = "Report Only Policies"
    #         Status = "Warning"
    #         Severity = "Medium"
    #         CurrentValue = $reportOnlyCount
    #         ExpectedValue = 0
    #         Notes = "Conditional Access policies exist in report-only mode."
    #     }
    # }

    # $noMfaAdmins = $mfaExport |
    #     Where-Object {
    #         $_.IsAdmin -and
    #         -not $_.IsMfaRegistered
    #     }

    # if ($noMfaAdmins.Count -gt 0) {

    #     $findings += [PSCustomObject]@{
    #         Category = "MFA"
    #         Setting = "Admin Accounts Without MFA"
    #         Status = "Fail"
    #         Severity = "Critical"
    #         CurrentValue = $noMfaAdmins.Count
    #         ExpectedValue = 0
    #         Notes = "Administrative accounts detected without MFA registration."
    #     }
    # }

    # if ($legacyExport.Count -gt 0) {

    #     $findings += [PSCustomObject]@{
    #         Category = "Authentication"
    #         Setting = "Legacy Authentication Usage"
    #         Status = "Fail"
    #         Severity = "High"
    #         CurrentValue = $legacyExport.Count
    #         ExpectedValue = 0
    #         Notes = "Legacy authentication sign-ins detected."
    #     }
    # }

    # -------------------------------------------------------------------------
    # Return Collector Object
    # -------------------------------------------------------------------------

    return [PSCustomObject]@{
        
        Collector = "Entra"

        Metadata = @{
            TenantId       = $context.TenantId
            CollectionTime = Get-Date
        }

        Health = @{
            Success    = ($CollectorErrors.Count -eq 0)
            ErrorCount = $CollectorErrors.Count
        }

        Summary = @{
            ConditionalAccessPolicies = $caPolicies.Count
            MFAUsers                  = $mfaExport.Count
            LegacyAuthSignIns         = $legacyExport.Count
        }

        Findings = $findings

        Errors = $CollectorErrors

        RawData = @{

            ConditionalAccess = $caExport

            MFARegistration = $mfaExport

            LegacyAuthentication = $legacyExport

            AuthenticationMethods = $AuthenticationMethods

            SecurityDefaults = $SecurityDefaults

            NamedLocations = $NamedLocations

            DirectoryRoles = $DirectoryRoles

            BreakGlassAccounts = $BreakGlassAccounts
        }
    }
}