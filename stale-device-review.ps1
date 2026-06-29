# Microsoft Graph

# Using this Connect cmd is a safety step as there is no write permissions
Connect-MgGraph -NoWelcome -Scopes "Device.Read.All","DeviceManagementManagedDevices.Read.All"

# Use this Connect cmd when the Delete Stage is to be used
# Connect-MgGraph -Scopes "Device.Read.All","Device.ReadWrite.All","DeviceManagementManagedDevices.Read.All"

# -----------------------------
# CONFIGURATION
# -----------------------------

# If a device hasn’t signed in (Entra) for 200 days → considered stale
# If a device synced with Intune within 180 days → considered active
$entraCutoffDays = 200
$intuneActiveDays = 180

$entraCutoff = (Get-Date).AddDays(-$entraCutoffDays)
$intuneCutoff = (Get-Date).AddDays(-$intuneActiveDays)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$outputAll           = ".\DeviceCleanup_FULL_$timestamp.csv"
$outputDelete        = ".\DeviceCleanup_DELETE_$timestamp.csv"
$outputDeleteTop50   = ".\DeviceCleanup_DELETE_TOP50_$timestamp.csv"
$outputKeep          = ".\DeviceCleanup_KEEP_$timestamp.csv"
$outputIntuneOnly    = ".\DeviceCleanup_Mismatch_IntuneOnly_$timestamp.csv"
$outputEntraOnly     = ".\DeviceCleanup_Mismatch_EntraOnly_$timestamp.csv"
$outputMissingId     = ".\DeviceCleanup_Intune_MissingDeviceId_$timestamp.csv"

Write-Host ""
Write-Host "Starting reconciliation..."
Write-Host "Entra inactivity cutoff: $entraCutoff"
Write-Host "Intune activity cutoff: $intuneCutoff"

# -----------------------------
# GET DATA
# -----------------------------
$entraDevices = Get-MgDevice -All -Property `
"id,deviceId,displayName,operatingSystem,trustType,accountEnabled,approximateLastSignInDateTime"

$intuneDevices = Get-MgDeviceManagementManagedDevice -All -Property `
"id,deviceName,azureADDeviceId,lastSyncDateTime,operatingSystem"

Write-Host ""
Write-Host "Entra devices:  $($entraDevices.Count)"
Write-Host "Intune devices: $($intuneDevices.Count)"

# -----------------------------
# BUILD LOOKUPS
# -----------------------------
$entraDeviceIds = @{}
foreach ($d in $entraDevices) {
    if ($d.DeviceId) {
        $entraDeviceIds[$d.DeviceId.Trim().ToLower()] = $true
    }
}

$intuneDeviceIds = @{}
foreach ($d in $intuneDevices) {
    if ($d.AzureADDeviceId) {
        $intuneDeviceIds[$d.AzureADDeviceId.Trim().ToLower()] = $true
    }
}

# -----------------------------
# INTUNE HEALTH CHECK
# -----------------------------
$intuneMissingId = $intuneDevices | Where-Object {
    -not $_.AzureADDeviceId
} | Select-Object DeviceName, LastSyncDateTime, OperatingSystem

$intuneMissingId | Export-Csv $outputMissingId -NoTypeInformation

# -----------------------------
# ACTIVE INTUNE DEVICES
# -----------------------------
$activeIntuneDevices = $intuneDevices | Where-Object {
    $_.LastSyncDateTime -and
    $_.LastSyncDateTime -ge $intuneCutoff -and
    $_.AzureADDeviceId
}

$protectedDeviceIds = @{}
$protectedDeviceNames = @{}

foreach ($d in $activeIntuneDevices) {
    $protectedDeviceIds[$d.AzureADDeviceId.Trim().ToLower()] = $true

    if ($d.DeviceName) {
        $protectedDeviceNames[$d.DeviceName.Trim().ToLower()] = $true
    }
}

# -----------------------------
# MISMATCH REPORTS
# -----------------------------
$intuneOnly = $intuneDevices | Where-Object {
    $_.AzureADDeviceId -and
    -not $entraDeviceIds.ContainsKey($_.AzureADDeviceId.Trim().ToLower())
} | Select-Object DeviceName, AzureADDeviceId, operatingSystem, LastSyncDateTime

$entraOnly = $entraDevices | Where-Object {
    $_.DeviceId -and
    -not $intuneDeviceIds.ContainsKey($_.DeviceId.Trim().ToLower())
} | Select-Object DisplayName, DeviceId, operatingSystem,trustType,accountEnabled, ApproximateLastSignInDateTime

$intuneOnly | Export-Csv $outputIntuneOnly -NoTypeInformation
$entraOnly  | Export-Csv $outputEntraOnly  -NoTypeInformation

# -----------------------------
# CLASSIFICATION
# -----------------------------
$results = @()

foreach ($device in $entraDevices) {

    $deviceIdKey = $null
    $deviceNameKey = $null

    if ($device.DeviceId) {
        $deviceIdKey = $device.DeviceId.Trim().ToLower()
    }

    if ($device.DisplayName) {
        $deviceNameKey = $device.DisplayName.Trim().ToLower()
    }

    # Activity
    $isStale = $false
    if ($device.ApproximateLastSignInDateTime) {
        $isStale = $device.ApproximateLastSignInDateTime -lt $entraCutoff
    }

    # Matching
    $matchById = $false
    $matchByName = $false

    if ($deviceIdKey -and $protectedDeviceIds.ContainsKey($deviceIdKey)) {
        $matchById = $true
    }

    if (-not $matchById -and $deviceNameKey -and $protectedDeviceNames.ContainsKey($deviceNameKey)) {
        $matchByName = $true
    }

    # Confidence
    if ($matchById) {
        $confidence = "High"
    }
    elseif ($matchByName) {
        $confidence = "Medium"
    }
    else {
        $confidence = "Low"
    }

    # Protection
    $isProtected = ($matchById -or $matchByName)

    # Intune presence
    $isInIntune = $false
    if ($deviceIdKey -and $intuneDeviceIds.ContainsKey($deviceIdKey)) {
        $isInIntune = $true
    }

    # Data quality
    
    if ($matchById) {
        $dataQuality = "High"
    }
    elseif ($matchByName) {
        $dataQuality = "Medium"
    }
    else {
        $dataQuality = "Low"
    }

    # Classification
    if ($isProtected) {
        $classification = "KEEP_IntuneActive"
    }
    elseif ($isStale) {
        $classification = "DELETE_Stale"
    }
    else {
        $classification = "KEEP_RecentActivity"
    }

    # Safe-to-delete logic (strict)
    $safeToDelete = $false
    if ($classification -eq "DELETE_Stale" -and
        $confidence -eq "Low" -and
        $isInIntune -eq $false) {

        $safeToDelete = $true
    }

    $results += [PSCustomObject]@{
        DeviceName          = $device.DisplayName
        EntraDeviceId       = $device.DeviceId
        OperatingSystem     = $device.OperatingSystem
        ApproxLastSignIn    = $device.ApproximateLastSignInDateTime
        IsInIntune          = $isInIntune
        MatchConfidence     = $confidence
        DataQuality         = $dataQuality
        Classification      = $classification
        SafeToDelete        = $safeToDelete
    }
}

# -----------------------------
# EXPORTS
# -----------------------------
$results | Export-Csv $outputAll -NoTypeInformation

$toDeleteFull = $results | Where-Object {
    $_.SafeToDelete -eq $true -and
    $_.OperatingSystem -like "Windows*"
}

$toDeleteTop50 = $toDeleteFull |
    Sort-Object ApproxLastSignIn |
    Select-Object -First 50

$toKeep = $results | Where-Object { $_.SafeToDelete -ne $true }

$toDeleteFull  | Export-Csv $outputDelete -NoTypeInformation
$toDeleteTop50 | Export-Csv $outputDeleteTop50 -NoTypeInformation
$toKeep        | Export-Csv $outputKeep -NoTypeInformation

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host ""
Write-Host "SUMMARY"
Write-Host "-------"
Write-Host "Entra-Safe to delete: $($toDeleteFull.Count)"
Write-Host "Entra-Top 50 ready:   $($toDeleteTop50.Count)"
Write-Host "Intune missing ID:    $($intuneMissingId.Count)"
Write-Host "Intune only:          $($intuneOnly.Count)"
Write-Host "Entra only:           $($entraOnly.Count)"

Write-Host ""
Write-Host "Confidence:"
Write-Host "  High:   $($results | Where-Object {$_.MatchConfidence -eq 'High'} | Measure-Object | % Count)"
Write-Host "  Medium: $($results | Where-Object {$_.MatchConfidence -eq 'Medium'} | Measure-Object | % Count)"
Write-Host "  Low:    $($results | Where-Object {$_.MatchConfidence -eq 'Low'} | Measure-Object | % Count)"

# -----------------------------
# OPTIONAL DELETE STAGE
# -----------------------------
# After review:
# 1. Confirm DELETE csv is correct
# 2. Uncomment below

<#
Write-Host "Deleting stale devices..."

# foreach ($device in $toDelete) {
foreach ($device in $toDeleteTop50) {
    try {
        Remove-MgDevice -DeviceId $device.EntraDeviceId -ErrorAction Stop
        Write-Host "Deleted: $($device.DeviceName)"
    }
    catch {
        Write-Warning "Failed: $($device.DeviceName)"
    }
}

Write-Host "✅ Deletion complete"
#>