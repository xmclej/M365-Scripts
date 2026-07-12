function Get-EntraLegacyAuthentication {

    [CmdletBinding()]
    param(
        [int]$DaysBack = 30
    )

    $LegacyClientApps = @(
        "Exchange ActiveSync"
        "Other clients"
        "Exchange Web Services"
        "IMAP4"
        "POP3"
        "SMTP"
        "Authenticated SMTP"
        "MAPI over HTTP"
        "Offline Address Book"
    )

    $StartDate = (
        Get-Date
    ).AddDays(-$DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")

    $AllSignIns = Get-MgAuditLogSignIn `
        -Filter "createdDateTime ge $StartDate" `
        -All `
        -ErrorAction Stop

    $AllSignIns |
        Where-Object {
            $_.ClientAppUsed -in $LegacyClientApps
        } |
        ForEach-Object {

            [PSCustomObject]@{
                CreatedDateTime         = $_.CreatedDateTime
                UserPrincipalName       = $_.UserPrincipalName
                AppDisplayName          = $_.AppDisplayName
                ClientAppUsed           = $_.ClientAppUsed
                IPAddress               = $_.IpAddress
                Location                = "$($_.Location.City), $($_.Location.CountryOrRegion)"
                ConditionalAccessStatus = $_.ConditionalAccessStatus

                Status = if ($_.Status.ErrorCode -eq 0) {
                    "Success"
                }
                else {
                    "Failure ($($_.Status.ErrorCode))"
                }
            }
        }
}