Connect-MgGraph -NoWelcome -Scopes "User.Read.All","User.ReadWrite.All"

$threshold = (Get-Date).AddDays(-45)

Get-MgUser -All -Property Id,AccountEnabled,SignInActivity,DisplayName,UserPrincipalName,UserType `
| Where-Object {
    $_.AccountEnabled -eq $true -and
    $_.UserType -eq "Guest" -and (
        -not $_.SignInActivity.LastSignInDateTime -or
        [DateTime]$_.SignInActivity.LastSignInDateTime -lt $threshold
    )
} `
| Select-Object DisplayName,
                UserPrincipalName,
                @{
                    Name='UserType'
                    Expression = { $_.UserType }
                },
                @{
                    Name='LastSignIn'
                    Expression = { $_.SignInActivity.LastSignInDateTime }
                },
                @{
                    Name='SignInStatus'
                    Expression = {
                        if ($_.SignInActivity.LastSignInDateTime) {
                            "Inactive"
                        } else {
                            "Never Signed In"
                        }
                    }
                } `
| Select-Object -First 50 `
| Export-Csv -Path "./disable-dormant-guests.csv" -NoTypeInformation -Encoding UTF8




#| ForEach-Object {
#Update-MgUser -UserId $_.Id -AccountEnabled:$false
#}