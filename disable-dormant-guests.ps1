Connect-MgGraph -NoWelcome -Scopes "User.Read.All","User.ReadWrite.All","AuditLog.Read.All"

$threshold = (Get-Date).AddDays(-45)

Get-MgUser -All -Property “Id,AccountEnabled,SignInActivity”
| Where-Object {
    $_.AccountEnabled -eq $true -and
    $_.UserType -eq "Guest" -and (
        -not $_.SignInActivity.LastSignInDateTime -or
        [DateTime]$_.SignInActivity.LastSignInDateTime -lt $threshold
    )
}
| Select-Object -First 50
| ForEach-Object {
Update-MgUser -UserId $_.Id -AccountEnabled:$false
}