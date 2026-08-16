$ErrorActionPreference = "Stop"

$adb = "C:\Android\Sdk\platform-tools\adb.exe"
$javaHome = "C:\Program Files\Eclipse Adoptium\jdk-21.0.3.9-hotspot"
$sdk = "C:\Android\Sdk"
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$env:GRADLE_OPTS = ""
$env:JAVA_OPTS = ""
$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:GRADLE_USER_HOME = Join-Path $env:USERPROFILE ".gradle"
$env:ANDROID_SERIAL = ""

if (-not (Test-Path $adb)) {
    throw "adb not found at $adb"
}

$last = Join-Path $appDir ".adb-device"
if (-not (& $adb devices | Select-String "`tdevice$")) {
    if (Test-Path $last) {
        $address = (Get-Content $last -Raw).Trim()
        Write-Host "Reconnecting $address ..."
        & $adb connect $address | Out-Host
    }
}

$devices = & $adb devices | Select-String "`tdevice$"
if (-not $devices) {
    Write-Host "No phone connected."
    Write-Host "Wireless debugging must stay on. If it dropped, pair again with connect-phone.ps1"
    exit 1
}

$mdns = & $adb mdns services
$found = [regex]::Match("$mdns", "(\d+\.\d+\.\d+\.\d+:\d+)")
if ($found.Success) {
    Set-Content -Path $last -Value $found.Value
}

Set-Location $appDir
Write-Host "Building and installing..."
& .\gradlew.bat installDebug --quiet
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $adb shell am start -n com.nazzil.app/com.iraqitube.app.MainActivity
Write-Host "App updated on the phone."
