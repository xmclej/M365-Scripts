function Get-EntraAuthenticationMethods {

    [CmdletBinding()]
    param()

    $authMethods = Get-MgPolicyAuthenticationMethodPolicy `
        -ErrorAction Stop

    [PSCustomObject]@{
        PolicyMigrationState = $authMethods.PolicyMigrationState

        AuthenticationMethods =
            $authMethods.AuthenticationMethodConfigurations |
            ForEach-Object {

                [PSCustomObject]@{
                    Id      = $_.Id
                    State   = $_.State
                    IncludedTargets = $_.IncludeTargets.Count
                    ExcludedTargets = $_.ExcludeTargets.Count
                }
            }

        RegistrationCampaign =
            $authMethods.RegistrationEnforcement
    }
}