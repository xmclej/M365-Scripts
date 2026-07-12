# -------------------------------------------------------------------------
# Admin MFA
# ------------------------------------------------------------------------
function Test-AdminMFA{
    param($CollectorData)

    $Section = "AdminMFA"
    Write-AssessmentLog `
        -Level "INFO" `
        -Component $Component `
        -Section $Section `
        -Message "Check started" `

    $AdminsWithoutMFA = 
        $CollectorData.RawData.MFARegistration |
        Where-Object {
            $_.IsAdmin -eq $true -and
            $_.IsMfaRegistered -eq $false
        }

    New-AssessmentFinding `
        -Id "E8-MFA-001" `
        -Framework "Essential Eight" `
        -Category "Authentication" `
        -Control "" `
        -Severity "High" `
        -Status $(if ($AdminsWithoutMFA.Count -eq 0) { "Pass" } else { "Fail" }) `
        -CurrentValue $AdminsWithoutMFA.Count `
        -ExpectedValue 0 `
        -Recommendation "" `
        -Evidence $AdminsWithoutMFA.DisplayName

    }
    

    if ($AdminsWithoutMFA.Count -gt 0) {

        $Findings += New-AssessmentFinding `
            -Id "E8-MFA-001" `
            -Framework "ACSC Essential Eight" `
            -Category "Multi-factor Authentication" `
            -Control "Administrative Accounts" `
            -Severity "Critical" `
            -Status "Pass" `
            -CurrentValue 0 `
            -ExpectedValue 0 `
            -Recommendation "All administrator accounts should be protected by MFA."
        }
    else {

        $Findings += New-AssessmentFinding `
            -Id "E8-MFA-001" `
            -Framework "ACSC Essential Eight" `
            -Category "Multi-factor Authentication" `
            -Control "Administrative Accounts" `
            -Severity "Critical" `
            -Status "Fail" `
            -CurrentValue $AdminsWithoutMFA.Count `
            -ExpectedValue 0 `
            -Recommendation "Register MFA for all administrative accounts." `
            -Evidence $AdminsWithoutMFA.UserPrincipalName
        }
    }
    Write-AssessmentLog `
        -Level "INFO" `
        -Component $Component `
        -Section $Section `
        -Message "Check finished" `
