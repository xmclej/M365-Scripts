# Import-Module Microsoft.Graph.Beta.DeviceManagement
# Import-Module Microsoft.Graph.Identity.SignIns

Connect-MgGraph -NoWelcome -Scopes `
    "DeviceManagementManagedDevices.Read.All",
    "BitlockerKey.Read.All"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = "./Dashboard-BitLocker_$timestamp.html"

# -------------------------------
# Get All Devices
# -------------------------------
Write-Host "Loading devices..."
$deviceTimer = [System.Diagnostics.Stopwatch]::StartNew()
$devices = Get-MgBetaDeviceManagementManagedDevice -All
$deviceTimer.Stop()
Write-Host "Device load time: $($deviceTimer.Elapsed.TotalSeconds) sec"

# -------------------------------
# Get All Keys
# -------------------------------
Write-Host "Loading keys..."
$deviceTimer = [System.Diagnostics.Stopwatch]::StartNew()
$keys = Get-MgInformationProtectionBitlockerRecoveryKey `
    -Property Id,DeviceId,CreatedDateTime `
    -All
$deviceTimer.Stop()
Write-Host "Keys load time: $($deviceTimer.Elapsed.TotalSeconds) sec"

# -------------------------------
# Build Recovery Key Lookup
# -------------------------------
$keyLookup = @{}

foreach($key in $keys)
{
    # $keyLookup[$key.DeviceId] = $true
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
        {$Status = "Missing Keys"}

    elseif($device.IsEncrypted -eq $false)
        {$Status = "Attention"}

    elseif($device.IsEncrypted -eq $null)
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
        Encryption = if($device.IsEncrypted)
                {"Encrypted"}
            elseif($device.IsEncrypted -eq $false)
                {"Not Encrypted"}
            else
                {"Unknown"}
        RecoveryKey     = $Recovery
        RecoveryDate    = $RecoveryDate
        TPM             = "Unknown"
        SecureBoot      = "Unknown"
        Status          = $Status
    }
}

$osOptions = $results |
    Select-Object -ExpandProperty OperatingSystem -Unique |
    Sort-Object |
    ForEach-Object {
        "<option value='$_'>$_</option>"
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
$tableRows = $results | ForEach-Object {

@"

<tr class="$($_.Status)"
    data-status="$($_.Status)"
    data-os="$($_.OperatingSystem)"
    data-recoverykey="$($_.RecoveryKey)">
<td>$($_.DeviceName)</td>
<td>$($_.UserPrincipalName)</td>
<td>$($_.OperatingSystem)</td>
<td>$($_.Encryption)</td>
<td>$($_.RecoveryKey)</td>
<td>$($_.RecoveryDate)</td>
<td>$($_.Status)</td>
</tr>
"@
}

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

.kpi-card{
    cursor:pointer;
    transition:0.2s;
}

.kpi-card:hover{
    transform:scale(1.03);
}

.kpi-card.active{
    border:4px solid #000;
}
</style>
</head>

<body>
<div class="container-fluid">

<h1 class="mb-3">BitLocker Dashboard</h1>
<p>Generated: $timestamp</p>

<!-- KPI CARDS -->
<div class="row mb-4">

    <div class="col-md-2">
        <div class="card bg-primary text-white kpi-card text-center">
            <div class="card-body">
                <h5>Total Devices</h5>
                <h2>$total</h2>
            </div>
        </div>
    </div>

    <div class="col-md-2">
        <div class="card bg-success text-white kpi-card text-center" data-filter="Healthy">
            <div class="card-body">
                <h5>Healthy</h5>
                <h2>$healthy</h2>
            </div>
        </div>
    </div>

    <!--
    <div class="col-md-2">
        <div class="card bg-danger text-white kpi-card text-center" data-filter="Critical">
            <div class="card-body">
                <h5>Critical</h5>
                <h2>$critical</h2>
            </div>
        </div>
    </div>
    -->

    <div class="col-md-2">
        <div class="card bg-warning text-dark kpi-card text-center" data-filter="Attention">
            <div class="card-body">
                <h5>Attention</h5>
                <h2>$attention</h2>
            </div>
        </div>
    </div>

    <div class="col-md-2">
        <div class="card bg-danger text-white kpi-card text-center" data-filter="Missing Keys">
            <div class="card-body">
                <h5>Missing Keys</h5>
                <h2>$missingKeys</h2>
            </div>
        </div>
    </div>

</div>

<!-- CHART -->
<div class="row mb-4">
    <div class="col-md-4">
        <canvas id="healthChart"></canvas>
    </div>
</div>

<!-- FILTERS -->
<div class="row mb-3">
    <div class="col-md-3">
        <select id="osFilter" class="form-select">
            <option value="">All Operating Systems</option>
            $($osOptions -join "`n")
        </select>
    </div>

    <div class="col-md-3">
        <button id="clearFilters"
                class="btn btn-secondary">
            Clear Filters
        </button>
    </div>

</div>

<!-- TABLE -->
<table id="deviceTable" class="table table-striped">
    <thead>
        <tr>
            <th>Device</th>
            <th>User</th>
            <th>OS</th>
            <th>Encryption</th>
            <th>Recovery Key</th>
            <th>Recovery Date</th>
            <th>Status</th>
        </tr>
    </thead>
    <tbody>
        $($tableRows -join "`n")
    </tbody>
</table>


<script>

let currentStatus = '';
let currentOS = '';

function applyFilters() {

    const rows =
        document.querySelectorAll(
            '#deviceTable tbody tr'
        );

    rows.forEach(row => {

        const rowStatus = row.dataset.status;
        const rowOS = row.dataset.os;

        const statusMatch =
            currentStatus === '' ||
            rowStatus === currentStatus;

        const osMatch =
            currentOS === '' ||
            rowOS === currentOS;

        row.style.display =
            (statusMatch && osMatch)
            ? ''
            : 'none';
    });
}

document.addEventListener('DOMContentLoaded', function () {

    const healthChart = new Chart(
        document.getElementById('healthChart'),
        {
            type: 'doughnut',
            data: {
                labels: [
                    'Healthy',
                    'Attention',
                    'Missing Keys',
                    'Encrypting'
                ],
                datasets: [{
                    data: [
                        HEALTHYCOUNT,
                        ATTENTIONCOUNT,
                        MISSINGKEYSCOUNT,
                        ENCRYPTINGCOUNT
                    ],
                    backgroundColor: [
                        '#198754',
                        '#ffc107',
                        '#dc3545',
                        '#0d6efd'
                    ]
                }]
            },
            options: {

                responsive: true,

                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                },

                onClick: (event, elements) => {

                    if (!elements.length)
                        return;

                    const index = elements[0].index;

                    currentStatus =
                        healthChart.data.labels[index];

                    document
                        .querySelectorAll('.kpi-card')
                        .forEach(card => {

                            card.classList.remove('active');

                            if (card.dataset.filter === currentStatus)
                                card.classList.add('active');
                        });

                    applyFilters();
                }
            }
        }
    );

    // KPI Cards

    document
        .querySelectorAll('.kpi-card')
        .forEach(card => {

            card.addEventListener('click', function () {

                document
                    .querySelectorAll('.kpi-card')
                    .forEach(c => c.classList.remove('active'));

                this.classList.add('active');

                currentStatus =
                    this.dataset.filter || '';

                applyFilters();

            });

        });

    // OS Filter

    document
        .getElementById('osFilter')
        .addEventListener('change', function () {

            currentOS = this.value;

            applyFilters();

        });

    // Clear Filters

    document
        .getElementById('clearFilters')
        .addEventListener('click', function () {

            currentStatus = '';
            currentOS = '';

            document
                .querySelectorAll('.kpi-card')
                .forEach(c => c.classList.remove('active'));

            document
                .getElementById('osFilter')
                .value = '';

            applyFilters();

        });

});

</script>

</body>
</html>
"@

$html = $html.Replace("HEALTHYCOUNT",$healthy)
$html = $html.Replace("ATTENTIONCOUNT",$attention)
$html = $html.Replace("MISSINGKEYSCOUNT",$missingKeys)
$html = $html.Replace("ENCRYPTINGCOUNT",$encrypting)

$html | Out-File $outputFile -Encoding UTF8

Write-Host "Dashboard saved to $outputFile" -ForegroundColor Green
