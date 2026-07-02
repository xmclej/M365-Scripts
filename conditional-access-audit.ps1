# -----------------------------
# CONNECT
# -----------------------------
Connect-MgGraph -NoWelcome -Scopes "Policy.Read.All","Directory.Read.All","User.Read.All"

$scriptTimer = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Retrieving Conditional Access policies..."

# -----------------------------
# OUTPUT
# -----------------------------
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputAll = ".\CA-Policy-Report_$timestamp.csv"
$outputTop10 = ".\CA-Policy-Top10_$timestamp.csv"

# -----------------------------
# ROLE MAP (built-in roles)
# -----------------------------
$roleMap = @{
    "62e90394-69f5-4237-9190-012177145e10" = "Global Administrator"
    "194ae4cb-b126-40b2-bd5b-6091b380977d" = "Security Administrator"
    "f28a1f50-f6e7-4571-818b-6a12f2af6b6c" = "SharePoint Administrator"
    "29232cdf-9323-42fd-ade2-1d097af3e4de" = "Exchange Administrator"
    "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9" = "Conditional Access Administrator"
    "729827e3-9c14-49f7-bb1b-9608f156bbb8" = "Helpdesk Administrator"
    "b0f54661-2d74-4c50-afa3-1ec803f12efe" = "Billing Administrator"
    "fe930be7-5e62-47db-91af-98c3a49a38b1" = "User Administrator"
    "c4e39bd9-1100-46d3-8c65-fb160da0071f" = "Authentication Administrator"
    "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3" = "Application Administrator"
    "158c047a-c907-4556-b7ef-446551a6b5f7" = "Cloud Application Administrator"
    "966707d0-3269-4727-9be2-8c3a10f19b9d" = "Privileged Authentication Administrator"
    "7be44c8a-adaf-4e2a-84d6-ab2649e08a13" = "Privileged Role Administrator"
    "e8611ab8-c189-46e8-94e1-60213ab1f814" = "Compliance Administrator"
}

# -----------------------------
# CACHE GROUPS
# -----------------------------
Write-Host "Caching groups..."
$cacheTimer = [System.Diagnostics.Stopwatch]::StartNew()

$allGroups = Get-MgGroup -All

$cacheTimer.Stop()
Write-Host "Group cache load time: $($cacheTimer.Elapsed.TotalSeconds) sec"

# -----------------------------
# FUNCTIONS
# -----------------------------
function Resolve-User {
    param ($id)

    if ($id -in @("All","None","GuestsOrExternalUsers")) {
        return $id
    }

    try {
        return (Get-MgUser -UserId $id -ErrorAction Stop).UserPrincipalName
    }
    catch {
        return "UNRESOLVED_USER:$id"
    }
}

function Resolve-Group {
    param ($id)

    if (-not $id -or $id -in @("All","None")) {
        return $id
    }

    $match = $allGroups | Where-Object { $_.Id -eq $id }

    if ($match) {
        return $match.DisplayName
    }
    else {
        return "UNRESOLVED_GROUP:$id"
    }
}

function Resolve-Role {
    param ($id)

    if (-not $id) { return $null }

    $normalized = ([string]$id).Trim().ToLower()

    if ($roleMap.ContainsKey($normalized)) {
        return $roleMap[$normalized]
    }

    return "UNKNOWN_ROLE:$normalized"
}

# -----------------------------
# GET POLICIES
# -----------------------------
$policies = Get-MgIdentityConditionalAccessPolicy
$results = @()

$resolveTimer = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($policy in $policies) {

    $conditions = $policy.Conditions

    # -----------------------------
    # RESOLVE TARGETS
    # -----------------------------
    $includeUsers = (
        $conditions.Users.IncludeUsers |
        ForEach-Object { Resolve-User $_ } |
        Where-Object { $_ }
    ) -join ","

    $excludeUsers = (
        $conditions.Users.ExcludeUsers |
        ForEach-Object { Resolve-User $_ } |
        Where-Object { $_ }
    ) -join ","

    $includeGroups = (
        $conditions.Users.IncludeGroups |
        ForEach-Object { Resolve-Group $_ } |
        Where-Object { $_ }
    ) -join ","

    $excludeGroups = (
        $conditions.Users.ExcludeGroups |
        ForEach-Object { Resolve-Group $_ } |
        Where-Object { $_ }
    ) -join ","

    $includeRoles = (
        $conditions.Users.IncludeRoles |
        ForEach-Object { Resolve-Role $_ } |
        Where-Object { $_ }
    ) -join ","

    $excludeRoles = (
        $conditions.Users.ExcludeRoles |
        ForEach-Object { Resolve-Role $_ } |
        Where-Object { $_ }
    ) -join ","

    # -----------------------------
    # CONTROLS
    # -----------------------------
    $grantControls = $policy.GrantControls.BuiltInControls -join ","
    $requiresMFA = $policy.GrantControls.BuiltInControls -contains "mfa"

    # -----------------------------
    # RISK DETECTION
    # -----------------------------
    $targetsAllUsers = $conditions.Users.IncludeUsers -contains "All"

    $hasExclusions = (
        ($conditions.Users.ExcludeUsers.Count -gt 0) -or
        ($conditions.Users.ExcludeGroups.Count -gt 0) -or
        ($conditions.Users.ExcludeRoles.Count -gt 0)
    )

    $targetsGlobalAdmin = $includeRoles -match "Global Administrator"

    $globalAdminNoMFA = $false
    $riskReasons = @()
    $highRisk = $false

    if ($policy.State -eq "enabled") {

        if ($targetsAllUsers -and -not $hasExclusions) {
            $highRisk = $true
            $riskReasons += "All users no exclusions"
        }

        if (-not $requiresMFA) {
            $highRisk = $true
            $riskReasons += "No MFA enforced"
        }

        if ($targetsGlobalAdmin -and -not $requiresMFA) {
            $highRisk = $true
            $globalAdminNoMFA = $true
            $riskReasons += "Global Admins without MFA"
        }
    }

    # Break-glass detection
    $hasBreakGlass = $excludeUsers -match "breakglass|emergency"

    # Report-only
    $isReportOnly = $policy.State -eq "enabledForReportingButNotEnforced"

    # Risk score
    $riskScore = $riskReasons.Count

    # -----------------------------
    # OUTPUT OBJECT
    # -----------------------------
    $results += [PSCustomObject]@{
        PolicyName     = $policy.DisplayName
        State          = $policy.State

        IncludeUsers   = $includeUsers
        ExcludeUsers   = $excludeUsers

        IncludeGroups  = $includeGroups
        ExcludeGroups  = $excludeGroups

        IncludeRoles   = $includeRoles
        ExcludeRoles   = $excludeRoles

        GrantControls  = $grantControls
        RequiresMFA    = $requiresMFA

        TargetsGlobalAdmin = $targetsGlobalAdmin
        GlobalAdminNoMFA   = $globalAdminNoMFA

        HighRisk      = $highRisk
        RiskScore     = $riskScore
        RiskReasons   = ($riskReasons -join "; ")

        HasBreakGlass = $hasBreakGlass
        ReportOnly    = $isReportOnly
    }
}

$resolveTimer.Stop()
Write-Host "Resolution time: $($resolveTimer.Elapsed.TotalSeconds) sec"

# -----------------------------
# EXPORT FULL REPORT
# -----------------------------
$results | Export-Csv $outputAll -NoTypeInformation

# -----------------------------
# TOP 10 RISKY POLICIES
# -----------------------------
$top10 = $results |
    Where-Object { $_.HighRisk -eq $true } |
    Sort-Object RiskScore -Descending |
    Select-Object -First 10

$top10 | Export-Csv $outputTop10 -NoTypeInformation

# -----------------------------
# SUMMARY
# -----------------------------
$scriptTimer.Stop()

Write-Host ""
Write-Host "SUMMARY"
Write-Host "-------"
Write-Host "Total policies: $($results.Count)"
Write-Host "High-risk policies: $($results | Where-Object {$_.HighRisk} | Measure-Object | ForEach-Object Count)"
Write-Host "Global Admin NOT protected by MFA: $($results | Where-Object {$_.GlobalAdminNoMFA} | Measure-Object | ForEach-Object Count)"
Write-Host ""
Write-Host "Top 10 risky exported: $outputTop10"
Write-Host "Full report: $outputAll"
Write-Host "Total runtime: $($scriptTimer.Elapsed.TotalSeconds) sec"

# -----------------------------
# FINAL HTML DASHBOARD (CHARTS + EXEC)
# -----------------------------
$htmlOutput = ".\CA-Policy-Dashboard_$timestamp.html"

$totalPolicies = $results.Count
$highRiskCount = ($results | Where-Object { $_.HighRisk }).Count
$adminRiskCount = ($results | Where-Object { $_.GlobalAdminNoMFA }).Count
$mfaCount = ($results | Where-Object { $_.RequiresMFA }).Count
$noMfaCount = $totalPolicies - $mfaCount

# Enhance dataset
$enhancedResults = $results | ForEach-Object {

    $severity = "Low"

    if ($_.GlobalAdminNoMFA) { $severity = "Critical" }
    elseif ($_.RiskScore -ge 3) { $severity = "High" }
    elseif ($_.RiskScore -eq 2) { $severity = "Medium" }

    $recommendation = ""

    if ($_.GlobalAdminNoMFA) {
        $recommendation = "Enforce MFA for all admin roles immediately"
    }
    elseif ($_.RiskReasons -match "No MFA") {
        $recommendation = "Enable MFA enforcement"
    }
    elseif ($_.RiskReasons -match "no exclusions") {
        $recommendation = "Add break-glass exclusions"
    }

    [PSCustomObject]@{
        PolicyName = $_.PolicyName
        State      = $_.State
        RiskScore  = $_.RiskScore
        Severity   = $severity
        HighRisk   = $_.HighRisk
        RequiresMFA = $_.RequiresMFA
        IncludeUsers = $_.IncludeUsers
        ExcludeUsers = $_.ExcludeUsers
        IncludeRoles = $_.IncludeRoles
        ExcludeRoles = $_.ExcludeRoles
        RiskReasons = $_.RiskReasons
        Recommendation = $recommendation
    }
}

$jsonData = $enhancedResults | ConvertTo-Json -Depth 5

$html = @"
<!DOCTYPE html>
<html>
<head>
<title>Conditional Access Security Dashboard</title>

<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<style>
body { background:#f4f6f8; }

/* Table handling */
.table td, .table th {
    max-width: 220px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

/* Roles column slightly wider */
.table td:nth-child(6), 
.table th:nth-child(6) {
    max-width: 320px;
}

/* Hover expand */
td:hover {
    white-space: normal;
    overflow: visible;
    background: #fff;
    z-index: 5;
    position: relative;
}

tr { cursor: pointer; }
tr.selected {
    outline: 2px solid #0078D4;
}
#detailsPanel {
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

/* Severity colouring */
tr.low { background:#ffffff; }
tr.medium { background:#fff4cc; }
tr.high { background:#ffe5cc; }
tr.critical { background:#ffcccc; }

/* Badges */
.badge.lowB { background:#107C10; }
.badge.mediumB { background:#FFB900; color:black; }
.badge.highB { background:#D83B01; }
.badge.criticalB { background:#A80000; }
</style>
</head>

<body>

<div class="container-fluid">

<h1 class="mb-3">Conditional Access Security Dashboard</h1>
<p>Generated: $timestamp</p>

<!-- KPI CARDS -->
<div class="row mb-4">
    <div class="col-md-4">
        <div class="card text-white bg-primary text-center p-3">
            <h5>Total Policies</h5>
            <h2>$totalPolicies</h2>
        </div>
    </div>

    <div class="col-md-4">
        <div class="card text-white bg-danger text-center p-3">
            <h5>High Risk</h5>
            <h2>$highRiskCount</h2>
        </div>
    </div>

    <div class="col-md-4">
        <div class="card text-white bg-dark text-center p-3">
            <h5>Admin No MFA</h5>
            <h2>$adminRiskCount</h2>
        </div>
    </div>
</div>

<!-- EXEC SUMMARY -->
<h3>Executive Summary</h3>
<ul>
<li>Total policies: <b>$totalPolicies</b></li>
<li>High-risk policies: <b>$highRiskCount</b></li>
<li>MFA Enabled: <b>$mfaCount</b></li>
<li>No MFA: <b>$noMfaCount</b></li>
</ul>

<!-- CHARTS -->
<div class="row mb-4">
    <div class="col-md-6">
        <canvas id="riskChart"></canvas>
    </div>
    <div class="col-md-6">
        <canvas id="mfaChart"></canvas>
    </div>
</div>

<!-- CONTROLS -->
<div class="mb-3">
    <label class="form-label"><b>Sort By</b></label>
    <select id="sortMode" class="form-select w-auto" onchange="applySort()">
        <option value="name">Policy Name (A–Z)</option>
        <option value="risk">Risk Score (High → Low)</option>
        <option value="severity">Severity (Critical → Low)</option>
    </select>
</div>

<!-- TABLE -->
<div class="table-responsive">
    <table id="policyTable" class="table table-striped table-bordered table-hover">
        <thead class="table-dark sticky-top">
            <tr>
            <th>Policy</th>
            <th>State</th>
            <th>Risk Score</th>
            <th>Severity</th>
            <th>MFA</th>
            <th>Roles</th>
            <th>Users</th>
            <th>Risk</th>
            </tr>
        </thead>
        <tbody></tbody>
    </table>
</div>

<h3 class="mt-5">Full Policy Detail (Audit View)</h3>
<p class="text-muted">All Conditional Access policies with full targeting and control data</p>

<div class="table-responsive">
    <table id="fullPolicyTable" class="table table-striped table-bordered table-sm">
        <thead class="table-dark sticky-top">
            <tr>
                <th>Policy</th>
                <th>State</th>
                <th>MFA</th>
                <th>Include Users</th>
                <th>Exclude Users</th>
                <th>Include Roles</th>
                <th>Exclude Roles</th>
                <th>Risk Score</th>
                <th>Severity</th>
                <th>Risk Reasons</th>
                <th>Recommendation</th>
            </tr>
        </thead>
        <tbody></tbody>
    </table>
</div>

</div>

<script>

let data = $jsonData;

// SORTING
function applySort() {
    let dropdown = document.getElementById("sortMode");
    if (!dropdown) return;

    let mode = dropdown.value;

    if (mode === "name") {
        data.sort((a,b) => (a.PolicyName||"").localeCompare(b.PolicyName||""));
    }

    if (mode === "risk") {
        data.sort((a,b) => (b.RiskScore||0) - (a.RiskScore||0));
    }

    if (mode === "severity") {
        const rank = {"Critical":4,"High":3,"Medium":2,"Low":1};

        data.sort((a,b) =>
            (rank[b.Severity]||0) - (rank[a.Severity]||0)
        );
    }

    renderTable();

}

// TABLE RENDER
function renderTable() {
    let tbody = document.querySelector("#policyTable tbody");
    tbody.innerHTML = "";

    data.forEach(p => {

        let row = document.createElement("tr");
        let severity = (p.Severity || "Low").toLowerCase();
        row.className = severity;

        let html = "";
        html += "<td title=\"" + (p.PolicyName||"").replace(/"/g,'&quot;') + "\">" + (p.PolicyName||"") + "</td>";
//        html += "<td title='" + (p.PolicyName||"") + "'>" + (p.PolicyName||"") + "</td>";
        html += "<td>" + (p.State||"") + "</td>";
        html += "<td>" + (p.RiskScore ?? "") + "</td>";
        html += "<td><span class='badge " + severity + "B'>" + (p.Severity||"") + "</span></td>";
        html += "<td>" + (p.RequiresMFA ? "✅":"❌") + "</td>";
        html += "<td title='" + (p.IncludeRoles||"").replace(/"/g,'&quot;') + "'>" + (p.IncludeRoles||"") + "</td>";
        html += "<td>" + (p.IncludeUsers||"") + "</td>";
        html += "<td>" + (p.RiskReasons||"") + "</td>";

        row.innerHTML = html;
        row.onclick = function() {
          showDetails(p);
        };
        tbody.appendChild(row);
    });
}

// FULL TABLE RENDER
function renderFullTable() {

    let tbody = document.querySelector("#fullPolicyTable tbody");
    tbody.innerHTML = "";

    data.forEach(p => {

        let row = document.createElement("tr");

        let severity = (p.Severity || "Low").toLowerCase();
        row.className = severity;

        let html = "";

        html += "<td>" + (p.PolicyName||"") + "</td>";
        html += "<td>" + (p.State||"") + "</td>";
        html += "<td>" + (p.RequiresMFA ? "✅" : "❌") + "</td>";

        html += "<td title=\"" + (p.IncludeUsers||"").replace(/"/g,'&quot;') + "\">" + (p.IncludeUsers||"") + "</td>";
        html += "<td title=\"" + (p.ExcludeUsers||"").replace(/"/g,'&quot;') + "\">" + (p.ExcludeUsers||"") + "</td>";

        html += "<td title=\"" + (p.IncludeRoles||"").replace(/"/g,'&quot;') + "\">" + (p.IncludeRoles||"") + "</td>";
        html += "<td title=\"" + (p.ExcludeRoles||"").replace(/"/g,'&quot;') + "\">" + (p.ExcludeRoles||"") + "</td>";

        html += "<td>" + (p.RiskScore ?? "") + "</td>";
        html += "<td>" + (p.Severity || "") + "</td>";
        html += "<td>" + (p.RiskReasons || "") + "</td>";
        html += "<td>" + (p.Recommendation || "") + "</td>";

        row.innerHTML = html;
        tbody.appendChild(row);
    });
}

// DEFAULT SORT = RISK
document.getElementById("sortMode").value = "risk";
applySort();
renderFullTable();

// CHARTS
let riskCounts = {Critical:0,High:0,Medium:0,Low:0};
data.forEach(p => {
    let key = p.Severity || "Low";
    if (!riskCounts[key]) riskCounts[key]=0;
    riskCounts[key]++;
});

new Chart(document.getElementById('riskChart'), {
    type: 'pie',
    data: {
        labels: Object.keys(riskCounts),
        datasets: [{
            data: Object.values(riskCounts),
            backgroundColor: ["#A80000","#D83B01","#FFB900","#107C10"]
        }]
    }
});

new Chart(document.getElementById('mfaChart'), {
    type: 'doughnut',
    data: {
        labels:["MFA Enabled","No MFA"],
        datasets:[{
            data: [$mfaCount,$noMfaCount],
            backgroundColor:["#107C10","#D83B01"]
        }]
    }
});

</script>

</body>
</html>
"@

$html | Out-File $htmlOutput -Encoding UTF8

Write-Host "✅ Full executive dashboard created: $htmlOutput"