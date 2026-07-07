# Import-Module Microsoft.Graph

Connect-MgGraph `
    -Scopes `
    "DeviceManagementManagedDevices.Read.All",
    "BitlockerKey.Read.All"

Select-MgProfile beta

$devices = Get-MgBetaDeviceManagementManagedDevice -All

# $keys = Get-MgInformationProtectionBitlockerRecoveryKey -All
$keys = Get-MgInformationProtectionBitlockerRecoveryKey `
    -Property Id,DeviceId,CreatedDateTime `
    -All
# -------------------------------
# Build Recovery Key Lookup
# -------------------------------
$keyLookup = @{}

foreach($key in $keys)
{
    $keyLookup[$key.DeviceId] = $true
    $keyLookup[$key.DeviceId] = $key
}

# -------------------------------
# Construct Dashboard Objects
# -------------------------------
$results = foreach($device in $devices)
{
$keyInfo = $keyLookup[$device.AzureAdDeviceId]

    if($keyInfo)
    {
        $Recovery = "Yes"
        $RecoveryDate = $keyInfo.CreatedDateTime
    }
    else
    {
        $Recovery = "No"
        $RecoveryDate = $null
    }

    if($Recovery -eq "No")
        {$Status = "Critical"}

    elseif($device.EncryptionState -eq "NotEncrypted")
        {$Status = "Attention"}

    elseif($device.EncryptionState -eq "EncryptionInProgress")
        {$Status = "Encrypting"}

    else
        {$Status = "Healthy"}

    [PSCustomObject]@{
        DeviceName          = $device.DeviceName
        UserPrincipalName   = $device.UserPrincipalName
        OperatingSystem     = $device.OperatingSystem
        OSVersion           = $device.OSVersion
        ComplianceState     = $device.ComplianceState
        LastSyncDateTime    = $device.LastSyncDateTime
        Encryption      = $device.EncryptionState
        RecoveryKey     = $Recovery
        TPM             = "Unknown"
        SecureBoot      = "Unknown"
        Status          = $Status
    }
}

# -------------------------------
# SUMMARY COUNTS
# -------------------------------
$total = $results.Count
$healthy  = ($results | Where-Object Status -eq "Healthy").Count
$critical = ($results | Where-Object Status -eq "Critical").Count
$attention = ($results | Where-Object Status -eq "Attention").Count
$encrypting = ($results | Where-Object Status -eq "Encrypting").Count
$missingKeys = ($results | Where-Object RecoveryKey -eq "No").Count

# -------------------------------
# HTML DASHBOARD
# -------------------------------
$html = @"
<!DOCTYPE html>
<html>
<head>
<title>BitLocker Dashboard</title>

<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<style>
body{
    font-family:Segoe UI;
    background:#f3f6fa;
}

table{
    width:100%;
    border-collapse:collapse;
}

th{
    background:#0078D4;
    color:white;
    padding:8px;
}

td{
    padding:8px;
}

.Healthy{
    background:#dff0d8;
}

.Attention{
    background:#fff3cd;
}

.Critical{
    background:#f8d7da;
}

.Encrypting{
    background:#cfe2ff;
}
</head>

<body>
<div class="container-fluid">

<h1 class="mb-3">Conditional Access Security Dashboard</h1>
<p>Generated: $timestamp</p>

<!-- KPI CARDS -->
<div class="row mb-4">
    <div class="col-md">
        <div class="card text-white bg-primary text-center p-3">
            <h5>Total Policies</h5>
            <h2>$totalPolicies</h2>
        </div>
    </div>



    

    <div class="row mb-4">
        <div class="col-md-6">
            <canvas id="healthChart"></canvas>
        </div>
    </div>
</div>

<script>
new Chart(document.getElementById('healthChart'), {
    type: 'doughnut',
    data: {
        labels: ['Healthy','Attention','Critical','Encrypting'],
        datasets: [{
            data: [
                HEALTHYCOUNT,
                ATTENTIONCOUNT,
                CRITICALCOUNT,
                ENCRYPTINGCOUNT
            ],
            backgroundColor:[
                '#198754',
                '#ffc107',
                '#dc3545',
                '#0d6efd'
            ]
        }]
    }
});
</script>



</body>
</html>
"@