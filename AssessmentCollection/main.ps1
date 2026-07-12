# Load shared functions
. "$PSScriptRoot\Shared\Shared-Utility.ps1"
# =================================================================
# Assessment Run Setup
# =================================================================
$ToolVersion = "1.0.0"
$Component = "MAIN"
$Section = "STARTUP"
$RunTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$FrameworkErrors = [System.Collections.Generic.List[object]]::new()

$OutputFolder = Join-Path $PSScriptRoot "Output\$RunTimestamp"
$LogFolder    = Join-Path $PSScriptRoot "Logs"

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null

$RunId = [guid]::NewGuid().ToString()
$LogFile = Join-Path $LogFolder "Assessment-$RunTimestamp.log"

Initialize-AssessmentLogging `
    -RunId $RunId `
    -LogFile $LogFile

Write-AssessmentLog `
    -Level "INFO" `
    -Component $Component `
    -Section $Section `
    -Message "Assessment run started. RunId=$RunId"

# =================================================================
# Connect to Microsoft Graph
# =================================================================
$Section = "GRAPH"

try {

    $Scopes = @(
        "Policy.Read.All",
        "UserAuthenticationMethod.Read.All",
        "AuditLog.Read.All",
        "Directory.Read.All"
    )

    Connect-MgGraph `
        -Scopes $Scopes `
        -NoWelcome `
        -ErrorAction Stop

    $Context = Get-MgContext

    Write-AssessmentLog `
        -Level "INFO" `
        -Component $Component `
        -Section $Section `
        -Message "Connected to tenant $($Context.TenantId)"

}
catch {
    $FrameworkErrors.Add(
        (Add-AssessmentError `
            -Component $Component `
            -Section $Section `
            -ErrorRecord $_)
    )

    throw
}

# =================================================================
# Define Collectors to Run
# =================================================================
$CollectorsToRun = @(
    @{
        Name     = "Entra"
        Script   = "$PSScriptRoot\Collectors\Get-EntraCollector.ps1"
        Function = "Get-EntraCollector"

        Params   = @{
            DaysBack = 30
        }
    }
)
# =================================================================
# Load Assessment Functions
# =================================================================

. "$PSScriptRoot\Assessments\Invoke-EntraAssessment.ps1"

# =================================================================
# Execute Collectors
# =================================================================

$CollectorResults = @()
$Section = "COLLECTORS"
foreach ($Collector in $CollectorsToRun) {

    try {

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "Running $($Collector.Name) collector"

        . $Collector.Script

        $Params = @{}
        foreach ($Key in $Collector.Params.Keys) {
            $Params[$Key] = $Collector.Params[$Key]
        }

        $Function = Get-Command `
            -Name $Collector.Function `
            -ErrorAction Stop

        $Result = & $Function.Name @Params

        $CollectorResults += $Result

        Write-AssessmentLog `
            -Level "INFO" `
            -Component $Component `
            -Section $Section `
            -Message "$($Collector.Name) collector completed successfully"

    }
    catch {
        $FrameworkErrors.Add(
            (Add-AssessmentError `
                -Component $Component `
                -Section $Section `
                -ErrorRecord $_)
        )
        # Write-AssessmentLog `
        #     -Level "ERROR" `
        #     -Component $Component `
        #     -Section $Section `
        #     -Message "$($Collector.Name) collector failed: $($_.Exception.Message)"
            
        $CollectorResults += [PSCustomObject]@{
            Collector = $Collector.Name

            Health = @{
                Success = $false
                Error   = $_.Exception.Message
            }
        }
    }
}

#  Debugging code
# $EntraResult = $CollectorResults |
#     Where-Object { $_.Collector -eq "Entra" }

# $EntraFindings = Invoke-EntraAssessment `
#     -CollectorData $EntraResult

# $EntraFindings | Format-Table

# =================================================================
# Execute Assessments
# =================================================================

$Findings = @()
$Section = "ASSESSMENT"
foreach ($Result in $CollectorResults) {

    switch ($Result.Collector) {

        "Entra" {

            Write-AssessmentLog `
                -Level "INFO" `
                -Component $Component `
                -Section $Section `
                -Message "Running Entra assessment"
            
            $OldComponent = $Component      # Saves value before sub-function call
            
            $Findings += Invoke-EntraAssessment `
                -CollectorData $Result
            
            $Component = $OldComponent      # restores value after sub-function call
        }
    }
}

# =================================================================
# Build Final Assessment Object
# =================================================================
$Section = "OBJECT"

$Assessment = [PSCustomObject]@{
    Metadata = @{
        RunId           = $RunId
        AssessmentDate  = Get-Date
        TenantId        = $Context.TenantId
        TenantAccount   = $Context.Account
        CollectorCount  = $CollectorResults.Count
        FindingCount    = $Findings.Count
        ToolVersion     = $ToolVersion
    }

    Findings   = $Findings

    Collectors = $CollectorResults
}

# =================================================================
# Export JSON
# =================================================================
$Section = "EXPORT"

$AssessmentFile = Join-Path `
    $OutputFolder `
    "Assessment.json"

$Assessment |
    ConvertTo-Json -Depth 50 |
    Out-File `
        -FilePath $AssessmentFile `
        -Encoding utf8

Write-AssessmentLog `
    -Level "INFO" `
    -Component $Component `
    -Section $Section `
    -Message "Assessment exported to $AssessmentFile"

# =================================================================
# Disconnect
# =================================================================
$Section = "COMPLETE"
# if (Get-MgContext) {
#     Disconnect-MgGraph | Out-Null
# }

Write-AssessmentLog `
    -Level "INFO" `
    -Component $Component `
    -Section $Section `
    -Message "Assessment completed successfully"
