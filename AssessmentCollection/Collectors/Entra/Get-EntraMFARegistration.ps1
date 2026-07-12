function Get-EntraMFARegistration {
    [CmdletBinding()]
    param()

    $mfaDetails = Get-MgReportAuthenticationMethodUserRegistrationDetail `
        -All `
        -ErrorAction Stop

    return ForEach-Object $user in $mfaDetails {

        [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            DisplayName = $user.UserDisplayName
            IsAdmin = $user.IsAdmin
            IsMfaRegistered = $user.IsMfaRegistered
            IsMfaCapable = $user.IsMfaCapable
            IsPasswordlessCapable = $user.IsPasswordlessCapable
            IsSsprRegistered = $user.IsSsprRegistered
            DefaultMfaMethod = $user.DefaultMfaMethod
            MethodsRegistered = $user.MethodsRegistered -join ";"
            PreferredMethod = $user.UserPreferredMethodForSecondaryAuth
        }
    }
}
