# This scripts purpose is to pull aall relevant data froma tenant for assessment
# Connect-MgGraph -NoWelcome -Scopes "Policy.Read.All"
# Get-MgIdentityConditionalAccessPolicy | ConvertTo-Json -Depth 10 | Out-File CA_policies.json

# Connect-MgGraph -NoWelcome -Scopes "Reports.Read.All"
# Get-MgReportAuthenticationMethodUserRegistrationDetail | Select-Object UserPrincipalName, IsMfaRegistered, MethodsRegistered, IsAdmin | Export-Csv MFA_registration.csv

# Get-MgAuditLogSignIn -Filter "clientAppUsed eq 'Other clients'" | Select-Object UserPrincipalName, ClientAppUsed, Status, CreatedDateTime | Export-Csv LegacyAuth_signins.csv


<#
.SYNOPSIS
    Pulls Conditional Access, MFA registration, and legacy auth sign-in data
    from an Entra ID tenant for an ACSC Essential Eight MFA (ML2) assessment.

.DESCRIPTION
    Exports three files to the output folder, ready to feed into the
    four-part assessment prompt:
      1. CA_policies.json          - all Conditional Access policies, with
                                      included/excluded users and groups
                                      resolved to display names
      2. MFA_registration.csv      - per-user MFA registration state, with
                                      registered methods flattened properly
                                      (fixes the System.String[] export bug)
      3. LegacyAuth_signins.csv    - sign-ins using legacy/basic auth
                                      protocols over the lookback window

.PARAMETER TenantId
    The Entra ID tenant to connect to. Omit to use interactive tenant selection.

.PARAMETER DaysBack
    How many days of sign-in logs to pull. Default 30. Entra sign-in logs
    are typically retained 30 days on non-P2 licenses, so don't go beyond
    that unless you know the tenant has a longer retention/export policy.

.PARAMETER OutputPath
    Folder to write exports to. A timestamped subfolder is created here.

.NOTES
    Requires the Microsoft.Graph PowerShell SDK:
        Install-Module Microsoft.Graph -Scope CurrentUser

    Requires delegated or app permissions (read-only):
        Policy.Read.All
        UserAuthenticationMethod.Read.All
        AuditLog.Read.All
        Directory.Read.All   (used only to resolve GUIDs to display names)

    Run with an account that holds at least Security Reader or Global
    Reader in the target tenant. No write scopes are requested.
#>

[CmdletBinding()]
param(
    [string]$TenantId,
    [int]$DaysBack = 30,
    [string]$OutputPath = ".\E8-Assessment-Export"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

$requiredModules = @("Microsoft.Graph.Authentication",
                      "Microsoft.Graph.Identity.SignIns",
                      "Microsoft.Graph.Reports",
                      "Microsoft.Graph.Users",
                      "Microsoft.Graph.Groups")

foreach ($mod in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "Installing missing module: $mod" -ForegroundColor Yellow
        Install-Module $mod -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $mod -ErrorAction Stop
}

$timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$exportDir  = Join-Path $OutputPath "Export-$timestamp"
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
$scopes = @(
    "Policy.Read.All",
    "UserAuthenticationMethod.Read.All",
    "AuditLog.Read.All",
    "Directory.Read.All"
)

if ($TenantId) {
    Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome
} else {
    Connect-MgGraph -Scopes $scopes -NoWelcome
}

$context = Get-MgContext
Write-Host "Connected to tenant: $($context.TenantId) as $($context.Account)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Helper: resolve a GUID to a display name (user, group, or role), with a
# small cache so we don't call Graph twice for the same ID
# ---------------------------------------------------------------------------

$identityCache = @{}

function Resolve-IdentityName {
    param([string]$Id)

    if ($Id -in @("All", "None", "GuestsOrExternalUsers")) { return $Id }
    if ($identityCache.ContainsKey($Id)) { return $identityCache[$Id] }

    $resolved = $Id  # fallback: leave as GUID if nothing matches
    try {
        $user = Get-MgUser -UserId $Id -Property "displayName,userPrincipalName" -ErrorAction Stop
        $resolved = "$($user.DisplayName) ($($user.UserPrincipalName))"
    } catch {
        try {
            $group = Get-MgGroup -GroupId $Id -Property "displayName" -ErrorAction Stop
            $resolved = "$($group.DisplayName) [group]"
        } catch {
            $resolved = "$Id [unresolved - may be a role template or deleted object]"
        }
    }

    $identityCache[$Id] = $resolved
    return $resolved
}

# ---------------------------------------------------------------------------
# 1. Conditional Access policies (with GUIDs resolved)
# ---------------------------------------------------------------------------

Write-Host "Pulling Conditional Access policies..." -ForegroundColor Cyan
$caPolicies = Get-MgIdentityConditionalAccessPolicy -All

$caExport = foreach ($policy in $caPolicies) {
    $includeUsers  = $policy.Conditions.Users.IncludeUsers  | ForEach-Object { Resolve-IdentityName $_ }
    $excludeUsers  = $policy.Conditions.Users.ExcludeUsers  | ForEach-Object { Resolve-IdentityName $_ }
    $includeGroups = $policy.Conditions.Users.IncludeGroups | ForEach-Object { Resolve-IdentityName $_ }
    $excludeGroups = $policy.Conditions.Users.ExcludeGroups | ForEach-Object { Resolve-IdentityName $_ }

    [PSCustomObject]@{
        DisplayName            = $policy.DisplayName
        State                  = $policy.State
        CreatedDateTime        = $policy.CreatedDateTime
        ModifiedDateTime       = $policy.ModifiedDateTime
        IncludeUsersResolved   = $includeUsers
        ExcludeUsersResolved   = $excludeUsers
        IncludeGroupsResolved  = $includeGroups
        ExcludeGroupsResolved  = $excludeGroups
        IncludeGuests          = $policy.Conditions.Users.IncludeGuestsOrExternalUsers
        ClientAppTypes         = $policy.Conditions.ClientAppTypes
        GrantControls          = $policy.GrantControls.BuiltInControls
        AuthStrengthRequired   = $policy.GrantControls.AuthenticationStrength.RequirementsSatisfied
        RawPolicy              = $policy
    }
}

$caPath = Join-Path $exportDir "CA_policies.json"
$caExport | ConvertTo-Json -Depth 12 | Out-File -FilePath $caPath -Encoding utf8
Write-Host "  -> $($caPolicies.Count) policies exported to $caPath" -ForegroundColor Green

$reportOnlyCount = ($caPolicies | Where-Object { $_.State -eq "enabledForReportingButNotEnforced" }).Count
if ($reportOnlyCount -gt 0) {
    Write-Host "  WARNING: $reportOnlyCount of $($caPolicies.Count) policies are report-only (not enforced)." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 2. MFA registration details (methods flattened properly this time)
# ---------------------------------------------------------------------------

Write-Host "Pulling MFA registration details..." -ForegroundColor Cyan
$mfaDetails = Get-MgReportAuthenticationMethodUserRegistrationDetail -All

# IsMfaRegistered, 
# IsMfaCapable, 
# IsPasswordlessCapable, 
# IsSsprRegistered, 
# IsSsprCapable, 
# MethodsRegistered, 
# LastUpdatedDateTime

$mfaExport = foreach ($u in $mfaDetails) {
    [PSCustomObject]@{
        UserPrincipalName       = $u.UserPrincipalName
        DisplayName             = $u.UserDisplayName
        IsAdmin                 = $u.IsAdmin
        IsMfaRegistered         = $u.IsMfaRegistered
        IsMfaCapable            = $u.IsMfaCapable
        IsSsprRegistered        = $u.IsSsprRegistered
        DefaultMfaMethod        = $u.DefaultMfaMethod
        MethodsRegistered       = ($u.MethodsRegistered -join ";")   # fixes the array-to-string bug
        IsPasswordlessCapable   = $u.IsPasswordlessCapable
        UserPreferredMethodForSecondaryAuth = $u.UserPreferredMethodForSecondaryAuth
    }
}

$mfaPath = Join-Path $exportDir "MFA_registration.csv"
$mfaExport | Export-Csv -Path $mfaPath -NoTypeInformation -Encoding utf8
Write-Host "  -> $($mfaExport.Count) users exported to $mfaPath" -ForegroundColor Green

$noMfaAdmins = $mfaExport | Where-Object { $_.IsAdmin -eq $true -and $_.IsMfaRegistered -eq $false }
if ($noMfaAdmins) {
    Write-Host "  WARNING: $($noMfaAdmins.Count) admin account(s) with no MFA registered:" -ForegroundColor Red
    $noMfaAdmins | ForEach-Object { Write-Host "    - $($_.UserPrincipalName)" -ForegroundColor Red }
}

# ---------------------------------------------------------------------------
# 3. Legacy authentication sign-ins over the lookback window
# ---------------------------------------------------------------------------

Write-Host "Pulling sign-in logs (last $DaysBack days, legacy auth only)..." -ForegroundColor Cyan

$startDate = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")

# Legacy/basic auth shows up in Graph sign-in logs as anything other than
# "Browser" or "Mobile Apps and Desktop clients" in clientAppUsed.
$legacyClientApps = @(
    "Exchange ActiveSync",
    "Other clients",
    "Exchange Web Services",
    "IMAP4",
    "POP3",
    "SMTP",
    "Authenticated SMTP",
    "MAPI over HTTP",
    "Offline Address Book"
)

$filter = "createdDateTime ge $startDate"
$allSignIns = Get-MgAuditLogSignIn -Filter $filter -All

$legacySignIns = $allSignIns | Where-Object { $_.ClientAppUsed -in $legacyClientApps }

$legacyExport = foreach ($s in $legacySignIns) {
    [PSCustomObject]@{
        CreatedDateTime   = $s.CreatedDateTime
        UserPrincipalName = $s.UserPrincipalName
        AppDisplayName    = $s.AppDisplayName
        ClientAppUsed     = $s.ClientAppUsed
        IPAddress         = $s.IpAddress
        Location          = "$($s.Location.City), $($s.Location.CountryOrRegion)"
        Status            = if ($s.Status.ErrorCode -eq 0) { "Success" } else { "Failure ($($s.Status.ErrorCode))" }
        ConditionalAccessStatus = $s.ConditionalAccessStatus
    }
}

$legacyPath = Join-Path $exportDir "LegacyAuth_signins.csv"
if ($legacyExport.Count -gt 0) {
    $legacyExport | Export-Csv -Path $legacyPath -NoTypeInformation -Encoding utf8
} else {
    # Write a header-only file so it's clear the export ran and genuinely
    # found nothing, rather than leaving a 0-byte file that looks broken.
    [PSCustomObject]@{
        CreatedDateTime=""; UserPrincipalName=""; AppDisplayName=""; ClientAppUsed="";
        IPAddress=""; Location=""; Status=""; ConditionalAccessStatus=""
    } | Select-Object * -First 0 | Export-Csv -Path $legacyPath -NoTypeInformation -Encoding utf8
}
Write-Host "  -> $($legacyExport.Count) legacy auth sign-ins (of $($allSignIns.Count) total in window) exported to $legacyPath" -ForegroundColor Green

if ($legacyExport.Count -gt 0) {
    Write-Host "  WARNING: active legacy auth sign-ins detected, this is a live bypass path if the blocking CA policy isn't enforced." -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# Wrap up
# ---------------------------------------------------------------------------

Write-Host "`nExport complete: $exportDir" -ForegroundColor Cyan
Write-Host "Files ready for the four-part assessment prompt:" -ForegroundColor Cyan
Write-Host "  - CA_policies.json"
Write-Host "  - MFA_registration.csv"
Write-Host "  - LegacyAuth_signins.csv"

Disconnect-MgGraph | Out-Null