Write-Host "=== Outlook Add-in Policy Check ===" -ForegroundColor Cyan

# Paths to check
$paths = @(
    "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Security",
    "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Resiliency",
    "HKCU:\Software\Microsoft\Office\Outlook\Addins",
    "HKCU:\Software\Microsoft\Office\16.0\Outlook\Resiliency"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Host "`n--- $path ---" -ForegroundColor Yellow
        Get-ItemProperty -Path $path | Format-List
    } else {
        Write-Host "`n--- $path does not exist ---" -ForegroundColor DarkGray
    }
}