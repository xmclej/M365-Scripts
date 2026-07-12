function Invoke-EntraAssessment {

    param(
        [Parameter(Mandatory)]
        $CollectorData
    )
    
    $Findings = @()
    $Component = "EntraAssessment"
    $Section = "STARTUP"

    Write-AssessmentLog `
        -Level "INFO" `
        -Component $Component `
        -Section $Section `
        -Message "Assessor started" `





    # -------------------------------------------------------------------------
    # Admin licences
    # ------------------------------------------------------------------------
    # $Section = "LICENCES"

    # Write-AssessmentLog `
    #     -Level "INFO" `
    #     -Component $Component `
    #     -Section $Section `
    #     -Message "Check started" `

    # $AdminsWithoutMFA = $CollectorData.RawData.MFARegistration |
    #     Where-Object {
    #         $_.IsAdmin -eq $true -and
    #         $_.IsMfaRegistered -eq $false
    #     }

    # if ($AdminsWithoutMFA.Count -gt 0) {

    #     $Findings += [PSCustomObject]@{
    #         Id             = "ENTRA-001"
    #         Category       = "Identity"
    #         Control        = "Administrative MFA"
    #         Severity       = "Critical"
    #         Status         = "Fail"
    #         CurrentValue   = $AdminsWithoutMFA.Count
    #         ExpectedValue  = 0
    #         Recommendation = "All administrator accounts should be protected by MFA."
    #         Framework      = "ACSC Essential Eight"
    #     }

    # }
    # else {

    #     $Findings += [PSCustomObject]@{
    #         Id             = "ENTRA-001"
    #         Category       = "Identity"
    #         Control        = "Administrative MFA"
    #         Severity       = "Critical"
    #         Status         = "Pass"
    #         CurrentValue   = 0
    #         ExpectedValue  = 0
    #         Recommendation = ""
    #         Framework      = "ACSC Essential Eight"
    #     }
    # }
    
    # Write-AssessmentLog `
    #     -Level "INFO" `
    #     -Component $Component `
    #     -Section $Section `
    #     -Message "Check finished" `

    # -------------------------------------------------------------------------
    # Admin MFA
    # ------------------------------------------------------------------------
#     $AdminsWithoutMFA = $CollectorData.RawData.MFARegistration |
#         Where-Object {
#             $_.IsAdmin -eq $true -and
#             $_.IsMfaRegistered -eq $false
#         }

#     if ($AdminsWithoutMFA.Count -gt 0) {

#         $Findings += [PSCustomObject]@{
#             Id             = "ENTRA-001"
#             Category       = "Identity"
#             Control        = "Administrative MFA"
#             Severity       = "Critical"
#             Status         = "Fail"
#             CurrentValue   = $AdminsWithoutMFA.Count
#             ExpectedValue  = 0
#             Recommendation = "All administrator accounts should be protected by MFA."
#             Framework      = "ACSC Essential Eight"
#         }

#     }
#     else {

#         $Findings += [PSCustomObject]@{
#             Id             = "ENTRA-001"
#             Category       = "Identity"
#             Control        = "Administrative MFA"
#             Severity       = "Critical"
#             Status         = "Pass"
#             CurrentValue   = 0
#             ExpectedValue  = 0
#             Recommendation = ""
#             Framework      = "ACSC Essential Eight"
#         }
#     }
#     # -------------------------------------------------------------------------
#     # Admin MFA
#     # ------------------------------------------------------------------------
#     $AdminsWithoutMFA = $CollectorData.RawData.MFARegistration |
#         Where-Object {
#             $_.IsAdmin -eq $true -and
#             $_.IsMfaRegistered -eq $false
#         }

#     if ($AdminsWithoutMFA.Count -gt 0) {

#         $Findings += [PSCustomObject]@{
#             Id             = "ENTRA-001"
#             Category       = "Identity"
#             Control        = "Administrative MFA"
#             Severity       = "Critical"
#             Status         = "Fail"
#             CurrentValue   = $AdminsWithoutMFA.Count
#             ExpectedValue  = 0
#             Recommendation = "All administrator accounts should be protected by MFA."
#             Framework      = "ACSC Essential Eight"
#         }

#     }
#     else {

#         $Findings += [PSCustomObject]@{
#             Id             = "ENTRA-001"
#             Category       = "Identity"
#             Control        = "Administrative MFA"
#             Severity       = "Critical"
#             Status         = "Pass"
#             CurrentValue   = 0
#             ExpectedValue  = 0
#             Recommendation = ""
#             Framework      = "ACSC Essential Eight"
#         }
#     }

    return $Findings
}