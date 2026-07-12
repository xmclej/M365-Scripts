function Get-EntraBreakGlassAccounts {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $MfaData
    )

    $Patterns = @(
        "breakglass"
        "break-glass"
        "emergency"
    )

    $MfaData | Where-Object {

        $UPN = $_.UserPrincipalName.ToLower()

        $Patterns | Where-Object {
            $UPN -like "*$_*"
        }
    }
}