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

    . "$PSScriptRoot\Entra\Get-EntraLegacyAuthentication.ps1"
    . "$PSScriptRoot\Entra\Get-EntraMFARegistration.ps1"
    . "$PSScriptRoot\Entra\Get-EntraAuthenticationMethods.ps1"
#     . "$PSScriptRoot\Entra\Get-EntraSecurityDefaults.ps1"
#     . "$PSScriptRoot\Entra\Get-EntraDirectoryRoles.ps1"
#     . "$PSScriptRoot\Entra\Get-EntraBreakGlassAccounts.ps1"
#     . "$PSScriptRoot\Entra\Get-EntraNamedLocations.ps1"
#     . "$PSScriptRoot\Entra\Get-EntraAuthenticationMethods.ps1"

    # -------------------------------------------------------------------------
    # FUNCTION: Resolve Identity Name
    # ------------------------------------------------------------------------
    function Resolve-IdentityName {

        param([string]$Id)
        $Section = "Resolve-IdentityName"

        try {

            if ([string]::IsNullOrWhiteSpace($Id)) {
                return $null
            }

            if ($Id -in @("All","None","GuestsOrExternalUsers")) {
                return $Id
            }

            if ($identityCache.ContainsKey($Id)) {
                return $identityCache[$Id]
            }

            $resolved = $Id

            try {

                $user = Get-MgUser `
                    -UserId $Id `
                    -Property DisplayName,UserPrincipalName `
                    -ErrorAction Stop

                $resolved = "$($user.DisplayName) ($($user.UserPrincipalName))"
            }
            catch {

                try {

                    $group = Get-MgGroup `
                        -GroupId $Id `
                        -Property DisplayName `
                        -ErrorAction Stop

                    $resolved = "$($group.DisplayName) [Group]"
                }
                catch {
                    $resolved = "$Id [Unresolved]"
                }
            }

            $identityCache[$Id] = $resolved

            return $resolved
        }
        catch {

            $CollectorErrors.Add(
                (Add-AssessmentError `
                    -Component $Component `
                    -Section $Section `
                    -ErrorRecord $_)
            )

            return "$Id [Resolution Failed]"
        }
    }

    # -------------------------------------------------------------------------
    # Main code starts here
    # ------------------------------------------------------------------------

    $CollectorErrors = @()
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
    # Identity Resolution Cache
    # -------------------------------------------------------------------------

    $identityCache = @{}

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

        $caExport = Get-MgIdentityConditionalAccessPolicy `
            -All `
            -ErrorAction Stop

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
            -Message "Retrieved $($legacyExport.Count) mfa registration records"

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

            SecurityDefaults = $SecurityDefaults

            AuthenticationMethods = $AuthenticationMethods

            NamedLocations = $NamedLocations

            DirectoryRoles = $DirectoryRoles

            BreakGlassAccounts = $BreakGlassAccounts
        }
    }
}