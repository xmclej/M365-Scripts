# -------------------------------------------------------------------------
# Initialise logging values to be used in all scripts
# -------------------------------------------------------------------------
function Initialize-AssessmentLogging {

    param(
        [string]$RunId,
        [string]$LogFile
    )

    $script:RunId = $RunId
    $script:LogFile = $LogFile
}

# -------------------------------------------------------------------------
# Write logs
# -------------------------------------------------------------------------
function Write-AssessmentLog {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$Section,

        [Parameter(Mandatory)]
        [string]$Message
    )

    try {

        $LogEntry = [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("s")
            Level     = $Level
            Component = $Component
            Section   = $Section
            Message   = $Message
            RunId     = $RunId
        }

        $LogEntry |
            ConvertTo-Json -Compress |
            Add-Content -Path $LogFile -Encoding UTF8

    }
    catch {
        Write-Warning "Failed to write log file: $($_.Exception.Message)"
    }
}

# -------------------------------------------------------------------------
# Write Errors
# -------------------------------------------------------------------------
function Add-AssessmentError {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$Section,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    Write-AssessmentLog `
        -Level "ERROR" `
        -Component $Component `
        -Section $Section `
        -Message $ErrorRecord.Exception.Message

    [PSCustomObject]@{
        Component    = $Component
        Section      = $Section
        Message      = $ErrorRecord.Exception.Message
        Exception    = $ErrorRecord.Exception.GetType().FullName
        Category     = $ErrorRecord.CategoryInfo.Category
        TargetObject = $ErrorRecord.TargetObject
        Timestamp    = Get-Date
    }
}
# -------------------------------------------------------------------------
# Findings Schema
# -------------------------------------------------------------------------
function New-AssessmentFinding {

    param(
        [string]$Id,
        [string]$Framework,
        [string]$Category,
        [string]$Control,
        [string]$Severity,
        [string]$Status,
        $CurrentValue,
        $ExpectedValue,
        [string]$Recommendation,
        [object[]]$Evidence
    )

    return [PSCustomObject]@{
        Id             = $Id
        Framework      = $Framework
        Category       = $Category
        Control        = $Control
        Severity       = $Severity
        Status         = $Status
        CurrentValue   = $CurrentValue
        ExpectedValue  = $ExpectedValue
        Recommendation = $Recommendation
        Evidence       = $Evidence
    }
}