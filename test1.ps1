# Reset session
Disconnect-MgGraph -ErrorAction SilentlyContinue
 
# Use beta profile (needed for SignInActivity)
Select-MgProfile beta
 
# Connect with correct permissions
Connect-MgGraph -Scopes "AuditLog.Read.All","Directory.Read.All"
 
# Verify who you are
Get-MgContext