<#
.SYNOPSIS
  Telefon ve saat uygulamalarının yayın (release) sürümünü derler ve doğru cihazlara kurar.

.DESCRIPTION
  Cihazlar modeline göre seçilir (telefon: SM-S928B, saat: SM-L340); bulunamayan cihaza kurulum yapılmaz.
  Uygulama asla kaldırılmaz (kaldırmak verileri siler). Saat Wi-Fi üzerinden bağlıdır; bağlı değilse
  mDNS ile bulunup bağlanmaya çalışılır. Bkz. docs/ARCHITECTURE.md §11 ve §15.

.EXAMPLE
  .\scripts\build-and-install.ps1              # ikisini derle, ikisini kur
  .\scripts\build-and-install.ps1 -Only watch  # yalnızca saat
  .\scripts\build-and-install.ps1 -NoBuild     # derlemeden, mevcut APK'ları kur
#>
param(
    [ValidateSet('both', 'phone', 'watch')]
    [string]$Only = 'both',
    [switch]$NoBuild,
    [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$flutter = 'C:\dev\flutter\bin\flutter.bat'
$phoneModel = 'SM_S928B'
$watchModel = 'SM_L340'
$phoneApk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
$watchApk = Join-Path $root 'wear\app\build\outputs\apk\release\app-release.apk'
$doPhone = $Only -ne 'watch'
$doWatch = $Only -ne 'phone'

function Find-Device([string]$model) {
    $line = & $adb devices -l | Where-Object { $_ -match "model:$model" -and $_ -match '\sdevice\s' } | Select-Object -First 1
    if ($line) { return ($line -split '\s+')[0] }
    return $null
}

function Connect-Watch {
    $serial = Find-Device $watchModel
    if ($serial) { return $serial }
    $service = & $adb mdns services | Where-Object { $_ -match '_adb-tls-connect' } | Select-Object -First 1
    if ($service) {
        $address = ($service -split '\s+')[2]
        & $adb connect $address | Out-Host
        Start-Sleep -Seconds 2
    }
    return Find-Device $watchModel
}

$timer = [Diagnostics.Stopwatch]::StartNew()

if (-not $NoBuild) {
    if ($doWatch) {
        Write-Host '== Saat derleniyor ==' -ForegroundColor Cyan
        Push-Location (Join-Path $root 'wear')
        try { & .\gradlew.bat assembleRelease --console=plain -q; if ($LASTEXITCODE) { throw 'Saat derlemesi başarısız' } }
        finally { Pop-Location }
        Write-Host ("Saat derlendi ({0:N0} sn)" -f $timer.Elapsed.TotalSeconds)
    }
    if ($doPhone) {
        Write-Host '== Telefon derleniyor ==' -ForegroundColor Cyan
        Push-Location $root
        try { & $flutter build apk --release; if ($LASTEXITCODE) { throw 'Telefon derlemesi başarısız' } }
        finally { Pop-Location }
        Write-Host ("Telefon derlendi ({0:N0} sn toplam)" -f $timer.Elapsed.TotalSeconds)
    }
}

if (-not $NoInstall) {
    if ($doPhone) {
        $phone = Find-Device $phoneModel
        if (-not $phone) { Write-Warning 'Telefon bulunamadı (USB kablosu takılı mı?). Telefona kurulmadı.' }
        else { & $adb -s $phone install -r $phoneApk; Write-Host "Telefona kuruldu ($phone)" -ForegroundColor Green }
    }
    if ($doWatch) {
        Write-Host '>> Saatin ekranını aç ve kurulum bitene kadar açık tut.' -ForegroundColor Yellow
        $watch = Connect-Watch
        if (-not $watch) { Write-Warning 'Saat bulunamadı (Kablosuz hata ayıklama açık mı, aynı Wi-Fi ağında mı?). Saate kurulmadı.' }
        else { & $adb -s $watch install -r $watchApk; Write-Host "Saate kuruldu ($watch)" -ForegroundColor Green }
    }
}

Write-Host ("Bitti: {0:N0} sn" -f $timer.Elapsed.TotalSeconds)
