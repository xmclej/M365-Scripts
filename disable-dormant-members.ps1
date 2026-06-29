Connect-MgGraph -NoWelcome -Scopes "User.Read.All","User.ReadWrite.All","AuditLog.Read.All"

$threshold = (Get-Date).AddDays(-45)

# Load exclusions from CSV 
$exclude = Import-Csv "./members-exclusion.csv" |
    Select-Object -ExpandProperty UserPrincipalName |
    ForEach-Object { $_.Trim() }

# Step 1: Get all dormant members 
$dormantMembers = Get-MgUser -All -Property Id,AccountEnabled,SignInActivity,DisplayName,UserPrincipalName,UserType `
| Where-Object {
    $_.AccountEnabled -eq $true -and
    $_.UserType -eq "Member" -and
    (
        -not $_.SignInActivity.LastSignInDateTime -or
        [DateTime]$_.SignInActivity.LastSignInDateTime -lt $threshold
    )
}

# Step 2: Take the first 100 users
$first50 = $dormantMembers | Select-Object -First 100

# Step 3: Apply exclusions
$finalList = $first50 | Where-Object {
    $_.UserPrincipalName -notin $exclude
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
| Export-Csv -Path "./disable-dormant-members.csv" -NoTypeInformation -Encoding UTF8

#Step 5: Disable accounts with failure output
# $finalList | ForEach-Object {
#     $user = $_
#     try {
#         Update-MgUser -UserId $user.Id -AccountEnabled:$false -ErrorAction Stop
#         Write-Host "Disabled: $($user.UserPrincipalName)" -ForegroundColor Green
#     }
#     catch {
#         Write-Host "FAILED to disable: $($user.UserPrincipalName)" -ForegroundColor Red
#     }
# }
