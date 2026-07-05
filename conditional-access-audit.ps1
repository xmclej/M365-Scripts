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
# CACHE GROUPS
# -----------------------------
Write-Host "Caching groups..."
$cacheTimer = [System.Diagnostics.Stopwatch]::StartNew()
# $allGroups = Get-MgGroup -All
$groupCache = @{}
Get-MgGroup -All | ForEach-Object {
    $groupCache[$_.Id] = $_.DisplayName}
$cacheTimer.Stop()
Write-Host "Group cache load time: $($cacheTimer.Elapsed.TotalSeconds) sec"

# -----------------------------
# CACHE Users
# -----------------------------
Write-Host "Caching users..."
$cacheTimer = [System.Diagnostics.Stopwatch]::StartNew()
$userCache = @{}
Get-MgUser -All |
ForEach-Object {
    $userCache[$_.Id] = $_.UserPrincipalName
}
# Write-Host "Cached $($userCache.Count) users"
$cacheTimer.Stop()
Write-Host "User cache load time: $($cacheTimer.Elapsed.TotalSeconds) sec"

# -----------------------------
# CACHE ROLES (built-in roles)
# -----------------------------
Write-Host "Caching directory roles..."
$cacheTimer = [System.Diagnostics.Stopwatch]::StartNew()
$roleMap = @{}
Get-MgRoleManagementDirectoryRoleDefinition -All |
    ForEach-Object {$roleMap[$_.Id.ToLower()] = $_.DisplayName}
# Write-Host "Cached $($roleMap.Count) role definitions"
$cacheTimer.Stop()
Write-Host "User cache load time: $($cacheTimer.Elapsed.TotalSeconds) sec"

# -----------------------------
# FUNCTIONS
# -----------------------------
function Resolve-User {
    param ($id)

    if ($id -in @("All","None","GuestsOrExternalUsers")) {
        return $id
    }

    if ($userCache.ContainsKey($id)) {
        return $userCache[$id]
    }

    return "UNRESOLVED_USER:$id"
}

function Resolve-Group {
    param ($id)
    if (-not $id -or $id -in @("All","None")) {
        return $id}
    if ($groupCache.ContainsKey($id)) {
        return $groupCache[$id]}
    else {return "UNRESOLVED_GROUP:$id"}
}

function Resolve-Role {
    param ($id)
    if (-not ($id)) {
        return $null}
    $normalized = $id.Trim().ToLower()
    if ($roleMap.ContainsKey($normalized)) {
        return $roleMap[$normalized]}
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
        Where-Object { $_ } ) -join ","

    $excludeUsers = (
        $conditions.Users.ExcludeUsers |
        ForEach-Object { Resolve-User $_ } |
        Where-Object { $_ } ) -join ","

    $includeGroups = (
        $conditions.Users.IncludeGroups |
        ForEach-Object { Resolve-Group $_ } |
        Where-Object { $_ } ) -join ","

    $excludeGroups = (
        $conditions.Users.ExcludeGroups |
        ForEach-Object { Resolve-Group $_ } |
        Where-Object { $_ } ) -join ","

    $includeRoles = (
        $conditions.Users.IncludeRoles |
        ForEach-Object { Resolve-Role $_ } |
        Where-Object { $_ } ) -join ","

    $excludeRoles = (
        $conditions.Users.ExcludeRoles |
        ForEach-Object { Resolve-Role $_ } |
        Where-Object { $_ } ) -join ","

    # -----------------------------
    # CONTROLS
    # -----------------------------
    $grantControls = $policy.GrantControls.BuiltInControls -join ","
    $requiresMFA = $policy.GrantControls.BuiltInControls -contains "mfa"
    $isBlockPolicy = $policy.GrantControls.BuiltInControls -contains "block"

    $hasSessionControls =
        $policy.SessionControls.SignInFrequency -or
        $policy.SessionControls.PersistentBrowser -or
        $policy.SessionControls.ApplicationEnforcedRestrictions -or
        $policy.SessionControls.CloudAppSecurity

    $hasDeviceControls =
        $policy.GrantControls.BuiltInControls -contains "compliantDevice" -or
        $policy.GrantControls.BuiltInControls -contains "domainJoinedDevice" -or
        $policy.GrantControls.BuiltInControls -contains "approvedApplication"

    $hasSecurityControl =
        $requiresMFA -or
        $isBlockPolicy -or
        $hasSessionControls -or
        $hasDeviceControls

    $controlType = switch ($true) {
        $requiresMFA       { "MFA"; break }
        $isBlockPolicy     { "Block"; break }
        $hasSessionControls { "Session"; break }
        $hasDeviceControls { "Device"; break }
        default            { "None" }
    }
    # -----------------------------
    # RISK DETECTION
    # -----------------------------
    $targetsAllUsers = $conditions.Users.IncludeUsers -contains "All"
    $hasExclusions = (
        ($conditions.Users.ExcludeUsers.Count -gt 0) -or
        ($conditions.Users.ExcludeGroups.Count -gt 0) -or
        ($conditions.Users.ExcludeRoles.Count -gt 0))

    $targetsGlobalAdmin = $includeRoles -match "Global Administrator"

    $globalAdminNoMFA = $false
    $riskReasons = @()
    $highRisk = $false

    if ($policy.State -eq "enabled") {
        if ($targetsAllUsers -and -not $hasExclusions) {
            $highRisk = $true
            $riskReasons += "All users no exclusions" }
        if (-not $hasSecurityControl) {
            $highRisk = $true
            $riskReasons += "No security control enforced" }
        if ($targetsGlobalAdmin -and -not $requiresMFA) {
            $highRisk = $true
            $globalAdminNoMFA = $true
            $riskReasons += "Global Admins without MFA" }}
    # Break-glass detection
    $hasBreakGlass = $excludeUsers -match "breakglass|emergency"
    # Report-only
    $isReportOnly = $policy.State -eq "enabledForReportingButNotEnforced"
    # Risk score
    $riskScore = $riskReasons.Count

    # -----------------------------
    # SUMMARY TARGETS (EXEC VIEW)
    # -----------------------------
    $includedSummary = @()
    if ($includeGroups) {
        $includeGroups.Split(',') | ForEach-Object {
            $includedSummary += "GROUP:$($_.Trim())"}}
    if ($includeRoles) {
        $includedSummary += "ROLES"}
    if ($includeUsers) {
        if ($includeUsers -eq "All") {
            $includedSummary += "ALLUSERS"}
        else {$includedSummary += "USERS"}}

    $excludedSummary = @()
    if ($excludeGroups) {
        $excludeGroups.Split(',') | ForEach-Object {
            $excludedSummary += "GROUP:$($_.Trim())"}}
    if ($excludeRoles) {
        $excludedSummary += "ROLES"}
    if ($excludeUsers) {
        $excludedSummary += "USERS"}

    # -----------------------------
    # CONDITIONS SUMMARY
    # -----------------------------
    $conditionsSummary = @()
    if ($conditions.UserRiskLevels.Count -gt 0) {
        $conditionsSummary += "User Risk: $($conditions.UserRiskLevels -join ', ')"}
    if ($conditions.SignInRiskLevels.Count -gt 0) {
        $conditionsSummary += "Sign-In Risk: $($conditions.SignInRiskLevels -join ', ')"}
    if ($conditions.Platforms.IncludePlatforms.Count -gt 0) {
        $conditionsSummary += "Platforms: $($conditions.Platforms.IncludePlatforms -join ', ')"}
    if ($conditions.ClientAppTypes.Count -gt 0) {
        $conditionsSummary += "Apps: $($conditions.ClientAppTypes -join ', ')"}
    $conditionsSummary = $conditionsSummary -join "; "

    # -----------------------------
    # OUTPUT OBJECT
    # -----------------------------
    $results += [PSCustomObject]@{
        PolicyName     = $policy.DisplayName
        State = switch ($policy.State) {
            "enabled" { "Enabled" }
            "disabled" { "Disabled" }
            "enabledForReportingButNotEnforced" { "Report-Only" }
            default { $policy.State }
        }
        IncludedSummary = ($includedSummary -join "|")
        ExcludedSummary = ($excludedSummary -join "|")
        IncludeUsers   = $includeUsers
        ExcludeUsers   = $excludeUsers
        IncludeGroups  = $includeGroups
        ExcludeGroups  = $excludeGroups
        IncludeRoles   = $includeRoles
        ExcludeRoles   = $excludeRoles
        GrantControls  = $grantControls
        RequiresMFA    = $requiresMFA        
        IsBlockPolicy     = $isBlockPolicy
        HasSessionControls = $hasSessionControls
        HasDeviceControls  = $hasDeviceControls
        HasSecurityControl = $hasSecurityControl
        ControlType     = $controlType
        TargetResources = $targetResources
        Conditions      = $conditionsSummary
        SessionControls = $sessionSummary
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
$reportOnlyCount = ($results | Where-Object { $_.ReportOnly } ).Count
$mfaCount = ($results | Where-Object { $_.RequiresMFA }).Count
$blockCount = ($results | Where-Object { $_.GrantControls -match "block" } ).Count
$noMfaCount = $totalPolicies - $mfaCount - $blockCount

$sessionControlCount = ( $results | Where-Object {$_.HasSessionControls} ).Count

$unprotectedCount = ( $results |
    Where-Object {
        -not $_.RequiresMFA -and
        -not $_.IsBlockPolicy -and
        -not $_.HasSessionControls
    } ).Count


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
    elseif ($_.RiskReasons -match "No security control") {
        $recommendation = "Apply MFA, device, block, or session controls"
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
        IncludedSummary = $_.IncludedSummary
        ExcludedSummary = $_.ExcludedSummary
        RequiresMFA = $_.RequiresMFA
        IsBlockPolicy = $_.IsBlockPolicy
        HasSessionControls = $_.HasSessionControls
        HasDeviceControls  = $_.HasDeviceControls
        HasSecurityControl = $_.HasSecurityControl
        ControlType        = $_.ControlType
        IncludeGroups = $_.IncludeGroups
        ExcludeGroups = $_.ExcludeGroups
        IncludeRoles = $_.IncludeRoles
        ExcludeRoles = $_.ExcludeRoles
        IncludeUsers = $_.IncludeUsers
        ExcludeUsers = $_.ExcludeUsers
        RiskReasons = $_.RiskReasons
        Recommendation = $recommendation
    }
}

# $enhancedResults |
#     Select-Object -First 1 |
#     Format-List *

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

/* Chart handling */
.chart-container {
    position: relative;
    height: 350px;
    max-height: 350px;
    max-width: 500px;
    margin: 0 auto;
}

/* Table handling */
#policyTable td,
#policyTable th {
    max-width: 250px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

#fullPolicyTable td,
#fullPolicyTable th {
    max-width: 350px;
    vertical-align: top;
}

#fullPolicyTable th {
    cursor: pointer;
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

    <div class="col-md-4">
        <div class="card text-white bg-dark text-center p-3">
            <h5>Report Only</h5>
            <h2>$reportOnlyCount</h2>
        </div>
    </div>
</div>

<!-- EXEC SUMMARY -->
<h3>Executive Summary</h3>
<ul>
<li>Total policies: <b>$totalPolicies</b></li>
<li>High-risk policies: <b>$highRiskCount</b></li>
<li>MFA Enabled: <b>$mfaCount</b></li>
<li>Block Policies: <b>$blockCount</b></li>
<li>No MFA / Not Blocking: <b>$noMfaCount</b></li>
</ul>

<!-- CHARTS -->
<div class="row mb-4">
    <div class="col-md-6">
        <div class="chart-container">
            <canvas id="riskChart"></canvas>
        </div>   
    </div>
    <div class="col-md-6">
        <div class="chart-container">
            <canvas id="mfaChart"></canvas>
        </div>
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
            <th>Included</th>
            <th>Excluded</th>
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
                <th onclick="sortDetailBy('policy')">Policy ↕</th>
                <th onclick="sortDetailBy('state')">State ↕</th>
                <th>MFA</th>
                <th>Include Groups</th>
                <th>Exclude Groups</th>
                <th>Include Roles</th>
                <th>Exclude Roles</th>
                <th>Include Users</th>
                <th>Exclude Users</th>
                <th>Target Resources</th>
                <th>Conditions</th>
                <th>Session Controls</th>
                <th onclick="sortDetailBy('risk')">Risk Score ↕</th>
                <th onclick="sortDetailBy('severity')">Severity ↕</th>
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

// BADGES
function renderTargetSummary(text) {
    if (!text) return "";
    return text.split("|")
        .map(item => {
            if (item === "ALLUSERS")
                return "<span class='badge bg-success me-1'>🌍 All Users</span>";
            if (item === "USERS")
                return "<span class='badge bg-primary me-1'>👤 Users</span>";
            if (item === "ROLES")
                return "<span class='badge bg-warning text-dark me-1'>🔑 Roles</span>";
            if (item.startsWith("GROUP:")) {
                let groupName = item.substring(6);
                let colour = "bg-secondary";
                if (/test/i.test(groupName))
                    colour = "bg-info text-dark";
                else if (/uat/i.test(groupName))
                    colour = "bg-warning text-dark";
                else if (/global/i.test(groupName))
                    colour = "bg-success";
                else if (/emergency/i.test(groupName))
                    colour = "bg-danger";
                return "<span class='badge " + colour + " me-1'>👥 "
                    + groupName + "</span>";
            }
            return item;
        })
        .join("<br>");
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
        html += "<td>" + (p.State||"") + "</td>";
        html += "<td>" + (p.RiskScore ?? "") + "</td>";
        html += "<td><span class='badge " + severity + "B'>" + (p.Severity||"") + "</span></td>";
        html += "<td>" + (p.RequiresMFA ? "✅":"❌") + "</td>";
        html += "<td>" + renderTargetSummary(p.IncludedSummary) + "</td>";
        html += "<td>" + renderTargetSummary(p.ExcludedSummary) + "</td>";
        html += "<td>" + (p.RiskReasons||"") + "</td>";

        row.innerHTML = html;
        row.onclick = function() {
          showDetails(p);
        };
        tbody.appendChild(row);
    });
}

// SORT DETAIL TABLE
function sortDetailBy(mode) {
    if (mode === "policy") {
        data.sort((a,b) =>
            (a.PolicyName || "")
                .localeCompare(b.PolicyName || "")
        );
    }
    else if (mode === "state") {
        data.sort((a,b) =>
            (a.State || "")
                .localeCompare(b.State || "")
        );
    }
    else if (mode === "risk") {
        data.sort((a,b) =>
            (b.RiskScore || 0)
          - (a.RiskScore || 0)
        );
    }
    else if (mode === "severity") {
        const rank = {
            Critical:4,
            High:3,
            Medium:2,
            Low:1
        };
        data.sort((a,b) =>
            (rank[b.Severity] || 0)
          - (rank[a.Severity] || 0)
        );
    }
    renderFullTable();
}

// WRAP TEXT ON COMMAS
function wrapCommas(text) {
    if (!text) return "";
    return text.replace(/,\s*/g, "<br>");
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
        html += "<td title=\"" + (p.IncludeGroups||"").replace(/"/g,'&quot;') + "\">" + wrapCommas(p.IncludeGroups||"") + "</td>";
        html += "<td title=\"" + (p.ExcludeGroups||"").replace(/"/g,'&quot;') + "\">" + wrapCommas(p.ExcludeGroups||"") + "</td>";
        html += "<td title=\"" + (p.IncludeRoles||"").replace(/"/g,'&quot;') + "\">" + wrapCommas(p.IncludeRoles||"") + "</td>";
        html += "<td title=\"" + (p.ExcludeRoles||"").replace(/"/g,'&quot;') + "\">" + wrapCommas(p.ExcludeRoles||"") + "</td>";
        html += "<td title=\"" + (p.IncludeUsers||"").replace(/"/g,'&quot;') + "\">" + wrapCommas(p.IncludeUsers||"") + "</td>";
        html += "<td title=\"" + (p.ExcludeUsers||"").replace(/"/g,'&quot;') + "\">" + wrapCommas(p.ExcludeUsers||"") + "</td>";
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
    },
    options: {
        responsive: true,
        maintainAspectRatio: false
    }
});

new Chart(document.getElementById('mfaChart'), {
    type: 'doughnut',
    data: {
        labels:["MFA Enabled","Block","Session Controls","No Controls"],
        datasets:[{
            data: [$mfaCount,$blockCount,$noMfaCount],
            backgroundColor:["#107C10","#0078D4","#FFB900","#D83B01"]
        }]
    },
    options: {
        responsive: true,
        maintainAspectRatio: false
    }
});

</script>

</body>
</html>
"@

$html | Out-File $htmlOutput -Encoding UTF8

Write-Host "✅ Full executive dashboard created: $htmlOutput"