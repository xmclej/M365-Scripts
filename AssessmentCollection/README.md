

## Collection Layer
Main.ps1
    |
    +-- Get-EntraCollector.ps1
            |
            +-- Assessment.json

## Build more collectors
Collectors
|
+-- Get-EntraCollector.ps1
+-- Get-ExchangeCollector.ps1
+-- Get-SharePointCollector.ps1
+-- Get-TeamsCollector.ps1
+-- Get-DefenderCollector.ps1
+-- Get-IntuneCollector.ps1

## Build an assessment engine
Assessments
|
+-- Invoke-EntraAssessment.ps1
+-- Invoke-ExchangeAssessment.ps1

Collection
     |
     V
Assessment Engine
     |
     V
Findings

## Create a stnadardized Finding Model
Example
[PSCustomObject]@{
    Id             = "ENTRA-001"
    Category       = "Identity"
    Control        = "Administrative MFA"
    Severity       = "Critical"
    Status         = "Fail"
    CurrentValue   = 2
    ExpectedValue  = 0
    Recommendation = "Ensure all administrative accounts are registered for MFA."
    Framework      = "ACSC Essential Eight"
}

## Generate HTMP reports
Assessment.json
      |
      V
Generate-Report.ps1
      |
      V
Assessment.html

## Build a web dashboard
Assessment.json
       |
       V
API
       |
       V
React Dashboard

or simpler

Assessment.json
       |
       V
Static HTML + JavaScript


# Working Flow
Collectors
    ↓
CollectorResults
    ↓
Assessment Functions
    ↓
Findings
    ↓
Build Final JSON