# Microsoft Graph
Connect-MgGraph -NoWelcome -Scopes "Device.Read.All","DeviceManagementManagedDevices.Read.All"
# Connect-MgGraph -Scopes "Device.Read.All","Device.ReadWrite.All","DeviceManagementManagedDevices.Read.All"

# -----------------------------
# CONFIGURATION
# -----------------------------
$entraCutoffDays = 180
$intuneActiveDays = 120

$entraCutoff = (Get-Date).AddDays(-$entraCutoffDays)
$intuneCutoff = (Get-Date).AddDays(-$intuneActiveDays)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$outputAll = ".\DeviceCleanup_FULL_$timestamp.csv"
$outputDelete = ".\DeviceCleanup_DELETE_$timestamp.csv"
$outputKeep = ".\DeviceCleanup_KEEP_$timestamp.csv"

Write-Host "Starting reconciliation..."
Write-Host "Entra inactivity cutoff: $entraCutoff"
Write-Host "Intune activity cutoff: $intuneCutoff"

# -----------------------------
# GET ENTRA DEVICES
# -----------------------------
$entraDevices = Get-MgDevice -All

Write-Host "Total Entra devices: $($entraDevices.Count)"

# -----------------------------
# GET INTUNE DEVICES
# -----------------------------
$intuneDevices = Get-MgDeviceManagementManagedDevice -All

Write-Host "Total Intune devices: $($intuneDevices.Count)"

# -----------------------------
# BUILD PROTECTED LIST (Intune active devices)
# -----------------------------
$activeIntuneDevices = $intuneDevices | Where-Object {
    $_.LastSyncDateTime -and $_.LastSyncDateTime -ge $intuneCutoff
}

# Create lookup (hashset style for performance)
$protectedDeviceIds = @{}
foreach ($d in $activeIntuneDevices) {
    if ($d.AzureADDeviceId) {
        $protectedDeviceIds[$d.AzureADDeviceId] = $true
    }
}

Write-Host "Active Intune devices (protected): $($protectedDeviceIds.Count)"

# -----------------------------
# CLASSIFY DEVICES
# -----------------------------
$results = @()

foreach ($device in $entraDevices) {

    $isStale = $false
    if ($device.ApproximateLastSignInDateTime) {
        $isStale = $device.ApproximateLastSignInDateTime -lt $entraCutoff
    }

    $isProtected = $protectedDeviceIds.ContainsKey($device.Id)

    $classification = ""

    if ($isProtected) {
        $classification = "KEEP_IntuneActive"
    }
    elseif ($isStale) {
        $classification = "DELETE_Stale"
    }
    else {
        $classification = "KEEP_RecentActivity"
    }

    $results += [PSCustomObject]@{
        DeviceName                         = $device.DisplayName
        EntraDeviceId                     = $device.Id
        OperatingSystem                   = $device.OperatingSystem
        TrustType                         = $device.TrustType
        AccountEnabled                    = $device.AccountEnabled
        ApproxLastSignIn                  = $device.ApproximateLastSignInDateTime
        IsProtectedByIntune               = $isProtected
        Classification                    = $classification
    }
}

# -----------------------------
# EXPORT RESULTS
# -----------------------------
$results | Export-Csv -Path $outputAll -NoTypeInformation

# Separate views
$toDelete = $results | Where-Object { $_.Classification -eq "DELETE_Stale" }
$toKeep   = $results | Where-Object { $_.Classification -ne "DELETE_Stale" }

$toDelete | Export-Csv -Path $outputDelete -NoTypeInformation
$toKeep   | Export-Csv -Path $outputKeep -NoTypeInformation

Write-Host ""
Write-Host "✅ Export complete:"
Write-Host "Full report:    $outputAll"
Write-Host "Delete list:    $outputDelete"
Write-Host "Keep list:      $outputKeep"

Write-Host ""
Write-Host "Summary:"
Write-Host "  KEEP (Intune active): $($results | Where-Object {$_.Classification -eq 'KEEP_IntuneActive'} | Measure-Object | Select -ExpandProperty Count)"
Write-Host "  KEEP (recent sign-in): $($results | Where-Object {$_.Classification -eq 'KEEP_RecentActivity'} | Measure-Object | Select -ExpandProperty Count)"
Write-Host "  DELETE candidates:     $($toDelete.Count)"

# -----------------------------
# OPTIONAL DELETE STAGE
# -----------------------------
# After review:
# 1. Confirm DELETE csv is correct
# 2. Uncomment below

<#
Write-Host "Deleting stale devices..."

foreach ($device in $toDelete) {
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