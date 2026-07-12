function Get-EntraConditionalAccess {

    $caPolicies = Get-MgIdentityConditionalAccessPolicy -All -ErrorAction Stop

    return ForEach-Object $policy in $caPolicies {

    [PSCustomObject]@{
        DisplayName           = $policy.DisplayName
        State                 = $policy.State
        CreatedDateTime       = $policy.CreatedDateTime
        ModifiedDateTime      = $policy.ModifiedDateTime

        IncludeUsersResolved  = @(
            $policy.Conditions.Users.IncludeUsers |
            ForEach-Object { Resolve-IdentityName $_ }
        )

        ExcludeUsersResolved  = @(
            $policy.Conditions.Users.ExcludeUsers |
            ForEach-Object { Resolve-IdentityName $_ }
        )

        IncludeGroupsResolved = @(
            $policy.Conditions.Users.IncludeGroups |
            ForEach-Object { Resolve-IdentityName $_ }
        )

        ExcludeGroupsResolved = @(
            $policy.Conditions.Users.ExcludeGroups |
            ForEach-Object { Resolve-IdentityName $_ }
        )

        IncludeGuests   = $policy.Conditions.Users.IncludeGuestsOrExternalUsers
        ClientAppTypes  = $policy.Conditions.ClientAppTypes
        GrantControls   = $policy.GrantControls.BuiltInControls
        # GrantControls         = $policy.GrantControls.BuiltInControls
        # RawPolicy             = $policy
    }
}