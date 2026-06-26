Connect-MgGraph -NoWelcome -Scopes "User.Read.All","User.ReadWrite.All","AuditLog.Read.All"

$threshold = (Get-Date).AddDays(-45)

# Exclusion list for guests
$exclude = @(
    "agoodwin_rcp.co.nz#EXT#@sitesafenz.onmicrosoft.com"
)

# Step 1: Get all dormant guests WITH exclusions applied here
$dormantGuests = Get-MgUser -All -Property Id,AccountEnabled,SignInActivity,DisplayName,UserPrincipalName,UserType `
| Where-Object {
    $_.AccountEnabled -eq $true -and
    $_.UserType -eq "Guest" -and
    ($exclude -notcontains $_.UserPrincipalName) -and
    (
        -not $_.SignInActivity.LastSignInDateTime -or
        [DateTime]$_.SignInActivity.LastSignInDateTime -lt $threshold
    )
}

# Step 2: Take the first 50 AFTER exclusions
$finalList = $dormantGuests | Select-Object -First 50

# Step 3: Export
$finalList | Select-Object Id,
                           DisplayName,
                           UserPrincipalName,
                           UserType,
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
| Export-Csv -Path "./disable-dormant-guests.csv" -NoTypeInformation -Encoding UTF8

# Step 4: Disable accounts (uncomment when ready)
# $finalList | ForEach-Object {
#     Update-MgUser -UserId $_.Id -AccountEnabled:$false
# }
