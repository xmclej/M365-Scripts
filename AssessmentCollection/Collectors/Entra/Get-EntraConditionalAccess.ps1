
function Get-EntraConditionalAccess {

    $caPolicies = Get-MgIdentityConditionalAccessPolicy -All -ErrorAction Stop

    foreach ($policy in $caPolicies) {

        [PSCustomObject]@{
            DisplayName           = $policy.DisplayName
            State                 = $policy.State
            CreatedDateTime       = $policy.CreatedDateTime
            ModifiedDateTime      = $policy.ModifiedDateTime
            IncludeUsersResolved  = @(
                $policy.Conditions.Users.IncludeUsers |
                ForEach-Object { Resolve-EntraIdentity $_ }
            )
            ExcludeUsersResolved  = @(
                $policy.Conditions.Users.ExcludeUsers |
                ForEach-Object { Resolve-EntraIdentity $_ }
            )
            IncludeGroupsResolved = @(
                $policy.Conditions.Users.IncludeGroups |
                ForEach-Object { Resolve-EntraIdentity $_ }
            )
            ExcludeGroupsResolved = @(
                $policy.Conditions.Users.ExcludeGroups |
                ForEach-Object { Resolve-EntraIdentity $_ }
            )
            IncludeGuests   = $policy.Conditions.Users.IncludeGuestsOrExternalUsers
            ClientAppTypes  = $policy.Conditions.ClientAppTypes
            GrantControls   = $policy.GrantControls.BuiltInControls
            # GrantControls         = $policy.GrantControls.BuiltInControls
            # RawPolicy             = $policy
        }
    }
}