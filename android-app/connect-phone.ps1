param(
    [Parameter(Mandatory = $true)]
    [string]$Address,
    [string]$Code
)

$adb = "C:\Android\Sdk\platform-tools\adb.exe"

if ($Code) {
    Write-Host "Pairing $Address ..."
    & $adb pair $Address $Code
}

Write-Host "Connecting $Address ..."
& $adb connect $Address
& $adb devices -l
