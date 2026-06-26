Connect-MgGraph -NoWelcome -Scopes "User.Read.All","User.ReadWrite.All","AuditLog.Read.All"

$threshold = (Get-Date).AddDays(-45)

# Add any member UPNs you want to exclude
$exclude = @(
    "accountspayable@sitesafe.org.nz",
    "BCTEST01@sitesafe.org.nz",
    "BCTEST02@sitesafe.org.nz",
    "board_room_christchurch@sitesafe.org.nz",
    "careers@sitesafe.org.nz",
    "chchbookings@sitesafe.org.nz",
    "comments@sitesafe.org.nz",
    "denise_makocommercial.co.nz#EXT#@sitesafenz.onmicrosoft.com",
    "dunedintrainingroom@sitesafe.org.nz",
    "graphicdesign@sitesafe.org.nz",
    "help@sitesafe.org.nz",
    "Ignatuis_precisionconstruction.co.nz#EXT#@sitesafenz.onmicrosoft.com"
)

# Step 1: Get all dormant members
$dormantMembers = Get-MgUser -All -Property Id,AccountEnabled,SignInActivity,DisplayName,UserPrincipalName,UserType `
| Where-Object {
    $_.AccountEnabled -eq $true -and
    $_.UserType -eq "Member" -and (
        -not $_.SignInActivity.LastSignInDateTime -or
        [DateTime]$_.SignInActivity.LastSignInDateTime -lt $threshold
    )
}

# Step 2: Take the first 50 BEFORE exclusions
$first50 = $dormantMembers | Select-Object -First 50

# Step 3: Apply exclusions
$finalList = $first50 | Where-Object {
    $exclude -notcontains $_.UserPrincipalName
}

# Step 4: Export
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
| Export-Csv -Path "./disable-dormant-members.csv" -NoTypeInformation -Encoding UTF8 `

# Step 5: Disable 
# $finalList | ForEach-Object {
#     Update-MgUser -UserId $_.Id -AccountEnabled:$false
# }