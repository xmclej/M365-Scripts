function Get-EntraNamedLocations {

    [CmdletBinding()]
    param()

    Get-MgIdentityConditionalAccessNamedLocation `
        -All `
        -ErrorAction Stop
}