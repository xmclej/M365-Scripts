# Microsoft Graph
Connect-MgGraph -NoWelcome -Scopes "User.Read.All","AuditLog.Read.All","Directory.Read.All"

# -----------------------------
# CONFIGURATION
# -----------------------------
$userInactiveDays = 120
$userCutoff = (Get-Date).AddDays(-$userInactiveDays)

# Path to exclusion CSV
$exclusionFile = ".\UserExclusions.csv"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$outputAll        = ".\UserCleanup_FULL_$timestamp.csv"
$outputDormant    = ".\UserCleanup_DORMANT_$timestamp.csv"
$outputTop50      = ".\UserCleanup_DORMANT_TOP50_$timestamp.csv"
$outputActive     = ".\UserCleanup_ACTIVE_$timestamp.csv"

Write-Host ""
Write-Host "Starting user inactivity review..."
Write-Host "Dormant cutoff: $userCutoff"

# -----------------------------
# GET USERS (important properties)
# -----------------------------
$users = Get-MgUser -All -Property `
"id,displayName,userPrincipalName,accountEnabled,createdDateTime,assignedLicenses,signInActivity"

Write-Host ""
Write-Host "Total users: $($users.Count)"

# -----------------------------
# LOAD EXCLUSIONS
# -----------------------------
$excludedUsers = @{}

if (Test-Path $exclusionFile) {
    $csv = Import-Csv $exclusionFile

    foreach ($row in $csv) {

        # Support multiple column names
        $upn = $null

        if ($row.UserPrincipalName) {
            $upn = $row.UserPrincipalName
        }
        # elseif ($row.UPN) {
        #     $upn = $row.UPN
        # }
        # elseif ($row.Email) {
        #     $upn = $row.Email
        # }

        if ($upn) {
            $excludedUsers[$upn.Trim().ToLower()] = $true
        }
    }

    Write-Host "Loaded exclusions: $($excludedUsers.Count)"
}
else {
    Write-Warning "Exclusion file not found: $exclusionFile"
}

# -----------------------------
# PROCESS USERS
# -----------------------------
$results = @()

foreach ($user in $users) {    
    # Exclusion check
    $isExcluded = $false
    $upnKey = $null

    if ($user.UserPrincipalName) {
        $upnKey = $user.UserPrincipalName.Trim().ToLower()

        if ($excludedUsers.ContainsKey($upnKey)) {
            $isExcluded = $true
        }
    }

    $lastSignIn = $null
    if ($user.SignInActivity) {
        $lastSignIn = $user.SignInActivity.LastSignInDateTime
    }

    # Inactive logic
    $isInactive = $false
    if ($lastSignIn) {
        $isInactive = $lastSignIn -lt $userCutoff
    }
    else {
        # Never signed in = treat as inactive candidate
        $isInactive = $true
    }

    # Licensed?
    $isLicensed = ($user.AssignedLicenses.Count -gt 0)

    # Confidence scoring
    if ($lastSignIn) {
        $confidence = "High"
    }
    else {
        $confidence = "Medium"   # never signed in (less certain)
    }

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
    if (-not $user.AccountEnabled) {
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

    if ($classification -eq "DORMANT" -and
        $confidence -eq "High" -and
        $user.AccountEnabled -eq $true -and
        -not $isExcluded) {

        $safeToDisable = $true
    }

    $results += [PSCustomObject]@{
        DisplayName        = $user.DisplayName
        UserPrincipalName  = $user.UserPrincipalName
        AccountEnabled     = $user.AccountEnabled
        LastSignIn         = $lastSignIn
        CreatedDate        = $user.CreatedDateTime
        IsLicensed         = $isLicensed
        IsExcluded         = $isExcluded
        MatchConfidence    = $confidence
        DataQuality        = $dataQuality
        Classification     = $classification
        SafeToDisable      = $safeToDisable
    }
}

# -----------------------------
# EXPORTS
# -----------------------------
$results | Export-Csv $outputAll -NoTypeInformation

# Dormant users
$dormantUsers = $results | Where-Object {
    $_.Classification -eq "DORMANT"
}

# Safe subset (Top 50)
$dormantTop50 = $results | Where-Object {
    $_.SafeToDisable -eq $true
} | Sort-Object LastSignIn | Select-Object -First 50

# Active users
$activeUsers = $results | Where-Object {
    $_.Classification -eq "ACTIVE"
}

$dormantUsers | Export-Csv $outputDormant -NoTypeInformation
$dormantTop50 | Export-Csv $outputTop50 -NoTypeInformation
$activeUsers  | Export-Csv $outputActive -NoTypeInformation

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host ""
Write-Host "SUMMARY"
Write-Host "-------"
Write-Host "Total users:        $($results.Count)"
Write-Host "Dormant users:      $($dormantUsers.Count)"
Write-Host "Safe to disable:    $($dormantTop50.Count)"
Write-Host "Already disabled:   $($results | Where-Object {$_.Classification -eq 'ALREADY_DISABLED'} | Measure-Object | % Count)"
Write-Host "Active users:       $($activeUsers.Count)"

Write-Host ""
Write-Host "Confidence:"
Write-Host "  High:   $($results | Where-Object {$_.MatchConfidence -eq 'High'} | Measure-Object | % Count)"
Write-Host "  Medium: $($results | Where-Object {$_.MatchConfidence -eq 'Medium'} | Measure-Object | % Count)"

Write-Host ""
Write-Host "Exclusions:"
Write-Host "  Total excluded users: $($excludedUsers.Count)"
Write-Host "  Excluded found in tenant: $($results | Where-Object {$_.IsExcluded} | Measure-Object | Select-Object -ExpandProperty Count)"
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