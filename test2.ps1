$Found = $false

$Paths = @(
    "HKCU:\Software\Policies\Microsoft\Office\Common\Security",
    "HKCU:\Software\Policies\Microsoft\Office\16.0\Common",
    "HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security"
)

foreach ($Path in $Paths) {

    if (!(Test-Path $Path)) {
        continue
    }

    $Props = Get-ItemProperty -Path $Path

    if (
        $Props.disableallactivex -eq 1 -or
        $Props.vbaoff -eq 1 -or
        $Props.blockcontentexecutionfrominternet -eq 1 -or
        $Props.vbawarnings -eq 4
    ) {
        $Found = $true
    }
}

if ($Found) {
    Write-Output "Non-compliant"
    exit 1
}
else {
    Write-Output "Compliant"
    exit 0
}