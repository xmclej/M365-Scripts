function Get-EntraDirectoryRoles {

    [CmdletBinding()]
    param()

    $Roles = Get-MgDirectoryRole

    foreach ($Role in $Roles) {

        $Members = Get-MgDirectoryRoleMember `
            -DirectoryRoleId $Role.Id

        [PSCustomObject]@{
            RoleName = $Role.DisplayName
            RoleId   = $Role.Id
            Members  = $Members
        }
    }
}