$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendPath = Join-Path $repoRoot 'backend'
$envPath = Join-Path $backendPath '.env'

function Test-Api {
    try {
        $response = Invoke-RestMethod -Uri 'http://127.0.0.1:3000/health' -TimeoutSec 3
        return $response.success -eq $true
    } catch {
        return $false
    }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker Desktop is not installed or is not in PATH.'
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'Node.js/npm is not installed or is not in PATH.'
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not installed or is not in PATH.'
}
if (-not (Test-Path $envPath)) {
    throw 'Missing backend/.env. Run setup-demo.ps1 once to create the configuration.'
}

Set-Location $repoRoot
docker compose up -d

if (-not (Test-Path (Join-Path $backendPath 'node_modules'))) {
    Push-Location $backendPath
    try { npm ci } finally { Pop-Location }
}

if (-not (Test-Api)) {
    $portOwners = @(Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique)
    foreach ($owner in $portOwners) {
        Stop-Process -Id $owner -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
    Start-Process powershell.exe -ArgumentList @(
        '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command',
        "Set-Location -LiteralPath '$backendPath'; npm start"
    ) | Out-Null
}

for ($attempt = 1; $attempt -le 30; $attempt++) {
    if (Test-Api) {
        Write-Host 'CSW430 API is online: http://127.0.0.1:3000' -ForegroundColor Green
        Write-Host 'Health: http://127.0.0.1:3000/health' -ForegroundColor Cyan
        break
    }
    Start-Sleep -Seconds 2
}

if (-not (Test-Api)) {
    throw 'API did not respond. Check the backend terminal for errors.'
}

$mobilePath = Join-Path $repoRoot 'mobile-app'
$deviceOutput = (& flutter devices 2>&1 | Out-String)
$hasAndroid = $deviceOutput -match '(?im)android|emulator'

if (-not $hasAndroid) {
    $emulatorOutput = (& flutter emulators 2>&1 | Out-String)
    $emulatorLine = $emulatorOutput -split "`r?`n" | Where-Object { $_ -match '^\s*\S+\s+•' } | Select-Object -First 1
    if ($emulatorLine) {
        $avdId = ($emulatorLine -split '•')[0].Trim()
        Write-Host "Starting Android emulator: $avdId" -ForegroundColor Cyan
        flutter emulators --launch $avdId
        for ($attempt = 1; $attempt -le 45; $attempt++) {
            Start-Sleep -Seconds 2
            $deviceOutput = (& flutter devices 2>&1 | Out-String)
            if ($deviceOutput -match '(?im)android|emulator') { $hasAndroid = $true; break }
        }
    }
}

if (-not $hasAndroid) {
    throw 'No Android emulator/AVD found. Create one in Android Studio Device Manager, then run this command again.'
}

Write-Host 'Starting Flutter app on Android emulator...' -ForegroundColor Green
Start-Process powershell.exe -ArgumentList @(
    '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command',
    "Set-Location -LiteralPath '$mobilePath'; flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000"
) | Out-Null
Write-Host 'Android emulator and Flutter app are starting.' -ForegroundColor Green
