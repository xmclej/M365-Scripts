function Test-ReportOnlyPolicies {

    param($CollectorData)

    $ReportOnlyPolicies =
        $CollectorData.RawData.ConditionalAccess |
        Where-Object {
            $_.State -eq "enabledForReportingButNotEnforced"
        }

    New-AssessmentFinding `
        -Id "BP-CA-001" `
        -Framework "Best Practice" `
        -Category "Conditional Access" `
        -Control "Report Only Policies" `
        -Severity "Medium" `
        -Status $(if ($ReportOnlyPolicies.Count -eq 0) { "Pass" } else { "Fail" }) `
        -CurrentValue $ReportOnlyPolicies.Count `
        -ExpectedValue 0 `
        -Recommendation "Convert report-only policies to enforced policies." `
        -Evidence $ReportOnlyPolicies.DisplayName
}
