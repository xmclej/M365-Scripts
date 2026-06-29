# Microsoft Graph

# -----------------------------
# MODE SELECTION
# -----------------------------
Write-Host ""
Write-Host "Select mode:"
Write-Host "  [V] View (read-only)"
Write-Host "  [Y] Dry Run (simulate deletion)"
Write-Host "  [D] Delete (actual deletion)"
Write-Host ""

do {
    $mode = Read-Host "Enter choice (V/Y/D)"
    $mode = $mode.Trim().ToUpper()
} while ($mode -notin @("V","Y","D"))

$deleteMode = $false
$dryRunMode = $false

if ($mode -eq "V") {
    Write-Host ""
    Write-Host "Running in VIEW mode (read-only)..."

    Connect-MgGraph -NoWelcome -Scopes "User.Read.All","AuditLog.Read.All","Directory.Read.All"
}
elseif ($mode -eq "Y") {
    Write-Host ""
    Write-Host "Running in DRY RUN mode (no changes will be made)..."

    Connect-MgGraph -NoWelcome -Scopes "User.Read.All","AuditLog.Read.All","Directory.Read.All"

    $dryRunMode = $true
}
elseif ($mode -eq "D") {
    Write-Host ""
    Write-Host "⚠️ Running in DELETE mode (write enabled)..."

    Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All","Directory.Read.All","User.ReadWrite.All"

    $deleteMode = $true
}`

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
$logFile = ".\UserCleanup_Log_$timestamp.txt"

$outputAll        = ".\UserCleanup_FULL_$timestamp.csv"

$outputMembers        = ".\UserCleanup_MEMBERS_$timestamp.csv"
$outputMembersTop50   = ".\UserCleanup_MEMBERS_TOP50_$timestamp.csv"

$outputGuests         = ".\UserCleanup_GUESTS_$timestamp.csv"
$outputGuestsTop50    = ".\UserCleanup_GUESTS_TOP50_$timestamp.csv"

$outputPrivileged     = ".\UserCleanup_PRIVILEGED_$timestamp.csv"

Write-Host ""
Write-Host "Starting user inactivity review..."
Write-Host "Dormant cutoff: $($userCutoff.ToString('dd/MM/yyyy HH:mm:ss'))"


# -----------------------------
# FUNCTIONS
# -----------------------------
function Write-Log {
    param([string]$message)

    $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $logFile -Value "$time - $message"
}

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

# -----------------------------
# GET USERS (important properties)
# -----------------------------
$users = Get-MgUser -All -Property `
"id,displayName,userPrincipalName,accountEnabled,userType,createdDateTime,assignedLicenses,signInActivity"

Write-Host ""
Write-Host "Total users: $($users.Count)"

# -----------------------------
# LOAD CSV EXCLUSIONS
# -----------------------------
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
    $upn = $user.UserPrincipalName.Trim().ToLower()
    $lastSignIn = $user.SignInActivity.LastSignInDateTime

    # Inactive logic
    $isInactive = $true     # Default to true to cater for Users never signed in = treat as inactive candidate
    if ($lastSignIn) {
        $isInactive = $lastSignIn -lt $userCutoff
    }

    # Exclusion flags
    $isExcluded  = $excludedUsers.ContainsKey($upn)
    $isEmergency = $emergencyUsers.ContainsKey($upn)
    $isPrivileged = $privilegedUsers.ContainsKey($upn)
    
    # Licensed?
    $isLicensed = ($user.AssignedLicenses.Count -gt 0)

    # Confidence scoring - never signed in (less certain) = Medium
    $confidence = if ($lastSignIn) { "High" } else { "Medium" }


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
    $safeToDisable = ($classification -eq "DORMANT" -and
        $confidence -eq "High" -and
        $user.UserType -eq "Member" -and
        $user.AccountEnabled -and
        -not ($isExcluded -or $isEmergency -or $isPrivileged)
    )

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
# TARGET USERS
# -----------------------------

$toDisable = $results | Where-Object {
    $_.SafeToDisable -eq $true
} | Sort-Object LastSignIn | Select-Object -First 50

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
# LOG START
# -----------------------------
Write-Log "Execution started"
Write-Log "Mode: $mode"
Write-Log "Users targeted: $($toDisable.Count)"

# -----------------------------
# EXECUTION
# -----------------------------
if ($dryRunMode -or $deleteMode) {

    Write-Host "Users in scope: $($toDisable.Count)"

    if ($deleteMode) {
        Write-Host ""
        Write-Host "⚠️ You are about to disable $($toDisable.Count) users"
        $confirm = Read-Host "Type YES to continue"

        if ($confirm -ne "YES") {
            Write-Warning "Cancelled"
            Write-Log "Cancelled by user"
            return
        }
    }

    foreach ($user in $toDisable) {

        if ($dryRunMode) {
            Write-Host "[DRY RUN] Would disable: $($user.UserPrincipalName)"
            Write-Log "[DRY RUN] Would disable: $($user.UserPrincipalName)"
            continue
        }

        if ($deleteMode) {
            try {
                Update-MgUser -UserId $user.UserPrincipalName -AccountEnabled:$false

                Write-Host "Disabled: $($user.UserPrincipalName)"
                Write-Log "Disabled: $($user.UserPrincipalName)"
            }
            catch {
                Write-Warning "Failed: $($user.UserPrincipalName)"
                Write-Log "FAILED: $($user.UserPrincipalName) | $_"
            }
        }
    }

    Write-Log "Execution complete"
}
else {
    Write-Host "VIEW mode - no changes"
}
