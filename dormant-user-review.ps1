# Microsoft Graph
Connect-MgGraph -NoWelcome -Scopes "User.Read.All","AuditLog.Read.All","Directory.Read.All"

# -----------------------------
# CONFIGURATION
# -----------------------------
$userInactiveDays = 120
$userCutoff = (Get-Date).AddDays(-$userInactiveDays)

# Path to exclusion CSV
$exclusionFile = ".\ExcludedAccounts.csv"
$emergencyFile = ".\EmergencyAccounts.csv"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"


$outputAll        = ".\UserCleanup_FULL_$timestamp.csv"

$outputMembers        = ".\UserCleanup_MEMBERS_$timestamp.csv"
$outputMembersTop50   = ".\UserCleanup_MEMBERS_TOP50_$timestamp.csv"

$outputGuests         = ".\UserCleanup_GUESTS_$timestamp.csv"
$outputGuestsTop50    = ".\UserCleanup_GUESTS_TOP50_$timestamp.csv"

$outputPrivileged     = ".\UserCleanup_PRIVILEGED_$timestamp.csv"

# $outputDormant    = ".\UserCleanup_DORMANT_$timestamp.csv"
# $outputTop50      = ".\UserCleanup_DORMANT_TOP50_$timestamp.csv"
# $outputActive     = ".\UserCleanup_ACTIVE_$timestamp.csv"
# $outputGuests     = ".\UserCleanup_GUESTS_$timestamp.csv"

Write-Host ""
Write-Host "Starting user inactivity review..."
Write-Host "Dormant cutoff: $($userCutoff.ToString('dd/MM/yyyy HH:mm:ss'))"

# -----------------------------
# GET USERS (important properties)
# -----------------------------
$users = Get-MgUser -All -Property `
"id,displayName,userPrincipalName,accountEnabled,userType,createdDateTime,assignedLicenses,signInActivity"

Write-Host ""
Write-Host "Total users: $($users.Count)"

# -----------------------------
# LOAD EXCLUSIONS
# -----------------------------
function Read-UPNList {
    param(
        [string]$path,
        [string]$label
    )

    $list = @{}

    if (Test-Path $path) {
        $csv = Import-Csv $path
        foreach ($row in $csv) {
            if ($row.UserPrincipalName) {
                $list[$row.UserPrincipalName.Trim().ToLower()] = $true
            }
        }
        Write-Host "Loaded $label $($list.Count)"
    }
    else {
        Write-Warning "$label file not found: $path"
    }

    return $list
}

$excludedUsers  = Read-UPNList $exclusionFile  "Exclusions"
$emergencyUsers = Read-UPNList $emergencyFile  "Emergency accounts"

# -----------------------------
# GET PRIVILEGED ROLE MEMBERS
# -----------------------------
$privilegedUsers = @{}
$privilegedReport = @()

$roles = Get-MgDirectoryRole

foreach ($role in $roles) {

    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id

    foreach ($m in $members) {

        if ($m.AdditionalProperties.userPrincipalName) {

            $upn = $m.AdditionalProperties.userPrincipalName.ToLower()

            $privilegedUsers[$upn] = $true

            $privilegedReport += [PSCustomObject]@{
                UserPrincipalName = $upn
                Role              = $role.DisplayName
            }
        }
    }
}

$privilegedReport | Export-Csv $outputPrivileged -NoTypeInformation

# -----------------------------
# PROCESS USERS
# -----------------------------
$results = @()

foreach ($user in $users) {    
    $upnKey = $null
    if ($user.UserPrincipalName) {
        $upnKey = $user.UserPrincipalName.Trim().ToLower()

        if ($excludedUsers.ContainsKey($upnKey)) {
            $isExcluded = $true
        }
    }

    # Exclusion flags
    $isExcluded  = $excludedUsers.ContainsKey($upnKey)
    $isEmergency = $emergencyUsers.ContainsKey($upnKey)
    $isPrivileged = $privilegedUsers.ContainsKey($upnKey)

    $lastSignIn = $user.SignInActivity.LastSignInDateTime

    # Inactive logic
    # Default to true to cater for Users never signed in = treat as inactive candidate
    $isInactive = $true 
    if ($lastSignIn) {
        $isInactive = $lastSignIn -lt $userCutoff
    }
    

    # Licensed?
    $isLicensed = ($user.AssignedLicenses.Count -gt 0)

    # Confidence scoring
    $confidence = if ($lastSignIn) { "High" } else { "Medium" }
    # never signed in (less certain) = Medium

    # Data quality
    if (-not $lastSignIn -and -not $user.CreatedDateTime) {
        $dataQuality = "Low"
    }
    elseif (-not $lastSignIn) {
        $dataQuality = "Medium"
    }
    else {
        $dataQuality = "High"
    }

    # Classification
    if ($user.UserType -eq "Guest") {
        $classification = "GUEST"
    }
    elseif (-not $user.AccountEnabled) {
        $classification = "ALREADY_DISABLED"
    }
    elseif ($isInactive) {
        $classification = "DORMANT"
    }
    else {
        $classification = "ACTIVE"
    }

    # Safe-to-disable logic
    $safeToDisable = $false

    # if ($classification -eq "DORMANT" -and
    #     $confidence -eq "High" -and
    #     $user.AccountEnabled -eq $true -and
    #     -not $isExcluded) {

    if ($classification -eq "DORMANT" -and
        $confidence -eq "High" -and
        $user.AccountEnabled -and
        -not $isExcluded -and
        -not $isEmergency -and
        -not $isPrivileged -and
        $user.UserType -eq "Member") {
        $safeToDisable = $true
    }

    $results += [PSCustomObject]@{
        DisplayName        = $user.DisplayName
        UserPrincipalName  = $user.UserPrincipalName
        UserType           = $user.UserType
        AccountEnabled     = $user.AccountEnabled
        CreatedDate        = if ($user.CreatedDateTime) { $user.CreatedDateTime.ToString('dd/MM/yyyy') } else { $null }
        LastSignIn         = if ($lastSignIn) { $lastSignIn.ToString('dd/MM/yyyy') } else { $null }

        IsLicensed         = $isLicensed

        IsExcluded         = $isExcluded
        IsEmergency        = $isEmergency
        IsPrivileged       = $isPrivileged

        MatchConfidence    = $confidence
        DataQuality        = $dataQuality
        Classification     = $classification
        SafeToDisable      = $safeToDisable
    }
}

# -----------------------------
# EXPORTS SPLIT BY TYPE
# -----------------------------
$members = $results | Where-Object { $_.UserType -eq "Member" }
$guests  = $results | Where-Object { $_.UserType -eq "Guest" }

$membersTop50 = $results |
    Where-Object { $_.SafeToDisable -eq $true -and $_.UserType -eq "Member" } |
    Sort-Object LastSignIn | Select-Object -First 50

$guestsTop50 = $results |
    Where-Object { 
        $_.Classification -eq "GUEST" -and
        $_.AccountEnabled -eq $true
    } |
    Sort-Object LastSignIn | Select-Object -First 50

# Exports
$results         | Export-Csv $outputAll -NoTypeInformation
$members         | Export-Csv $outputMembers -NoTypeInformation
$membersTop50    | Export-Csv $outputMembersTop50 -NoTypeInformation
$guests          | Export-Csv $outputGuests -NoTypeInformation
$guestsTop50     | Export-Csv $outputGuestsTop50 -NoTypeInformation

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host ""
Write-Host "SUMMARY"
Write-Host "-------"
Write-Host "Total users: $($results.Count)"
Write-Host "Members:     $($members.Count)"
Write-Host "Guests:      $($guests.Count)"
Write-Host ""
Write-Host "Safe to disable (Members): $($membersTop50.Count)"
Write-Host "Safe to disable (Guests): $($guestsTop50.Count)"
Write-Host ""
Write-Host "Already disabled:   $($results | Where-Object {$_.Classification -eq 'ALREADY_DISABLED'} | Measure-Object | ForEach-Object Count)"
Write-Host ""
Write-Host "Exclusions:"
Write-Host "  CSV exclusions: $($excludedUsers.Count)"
Write-Host "  Emergency:      $($emergencyUsers.Count)"
Write-Host "  Privileged:     $($privilegedUsers.Count)"
Write-Host ""
# -----------------------------
# OPTIONAL DISABLE STAGE
# -----------------------------
<#
Write-Host "Disabling dormant users..."

foreach ($user in $dormantTop50) {
    try {
        Update-MgUser -UserId $user.UserPrincipalName -AccountEnabled:$false
        Write-Host "Disabled: $($user.UserPrincipalName)"
    }
    catch {
        Write-Warning "Failed: $($user.UserPrincipalName)"
    }
}

Write-Host "✅ Disable complete"
#>