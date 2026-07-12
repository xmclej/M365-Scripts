function Get-EntraSecurityDefaults {

    [CmdletBinding()]
    param()

    Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy `
        -ErrorAction Stop
}