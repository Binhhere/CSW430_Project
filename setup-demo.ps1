<#
.SYNOPSIS
    Prepares and starts the CSW430 local demonstration.

.DESCRIPTION
    Checks the tools required by this repository, installs missing desktop
    tools through winget when available, creates the local backend .env file,
    installs project dependencies, starts PostgreSQL and the API, and starts
    Flutter when an Android device/emulator is available.

    This script does not delete files, reset Docker volumes, commit, or push.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\setup-demo.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\setup-demo.ps1 -NoApp
#>

[CmdletBinding()]
param(
    [switch]$NoApp,
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendPath = Join-Path $repoRoot 'backend'
$mobilePath = Join-Path $repoRoot 'mobile-app'

function Write-Step([string]$Message) {
    Write-Host "`n== $Message ==" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

function Has-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-WingetPackage([string]$Id, [string]$Name) {
    if ($SkipInstall) {
        Write-Warn "$Name is missing. Automatic installation was skipped."
        return $false
    }

    if (-not (Has-Command 'winget')) {
        throw "winget is not available. Install App Installer from Microsoft Store, then run this script again."
    }

    Write-Host "Installing $Name ($Id)..." -ForegroundColor DarkCyan
    & winget install --exact --id $Id --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget could not install $Name. Install it manually and run this script again."
    }

    Refresh-Path
    Write-Ok "$Name installation finished"
    return $true
}

function Ensure-Command([string]$Command, [string]$PackageId, [string]$DisplayName) {
    if (Has-Command $Command) {
        Write-Ok "$DisplayName detected"
        return
    }

    [void](Install-WingetPackage $PackageId $DisplayName)
    if (-not (Has-Command $Command)) {
        throw "$DisplayName is still unavailable in this terminal. Close and reopen PowerShell, then run this script again."
    }
    Write-Ok "$DisplayName detected after installation"
}

function Ensure-Flutter {
    if (Has-Command 'flutter') {
        Write-Ok 'Flutter SDK detected'
        return
    }

    if ($SkipInstall) {
        Write-Warn 'Flutter SDK is missing. Automatic installation was skipped.'
        throw 'Install Flutter SDK and run this script again.'
    }

    Write-Host 'Flutter is not distributed as a stable winget package on this machine.' -ForegroundColor DarkCyan
    Write-Host 'Downloading the latest official Windows stable Flutter SDK...' -ForegroundColor DarkCyan
    $flutterRoot = Join-Path $env:LOCALAPPDATA 'flutter'
    if (-not (Test-Path (Join-Path $flutterRoot 'bin\flutter.bat'))) {
        $releaseIndex = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
        $stableHash = $releaseIndex.current_release.stable
        $release = $releaseIndex.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1
        if (-not $release) {
            throw 'Could not find the current stable Flutter Windows release.'
        }
        $archiveUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/$($release.archive)"
        $archivePath = Join-Path $env:TEMP ([IO.Path]::GetFileName($release.archive))
        Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath
        Expand-Archive -LiteralPath $archivePath -DestinationPath $env:LOCALAPPDATA -Force
        Remove-Item -LiteralPath $archivePath -Force
    }

    $flutterBin = Join-Path $flutterRoot 'bin'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $flutterBin) {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$flutterBin", 'User')
    }
    Refresh-Path
    if (-not (Has-Command 'flutter')) {
        throw 'Flutter was installed, but this terminal cannot find it. Close and reopen PowerShell, then run this script again.'
    }
    Write-Ok 'Flutter SDK detected after installation'
}

function Find-AndroidStudio {
    $candidates = @(
        (Join-Path ${env:ProgramFiles} 'Android\Android Studio\bin\studio64.exe'),
        (Join-Path ${env:LOCALAPPDATA} 'Programs\Android Studio\bin\studio64.exe')
    )
    return $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Find-SdkManager {
    $sdkRoot = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    if (-not (Test-Path $sdkRoot)) { return $null }
    return Get-ChildItem -LiteralPath $sdkRoot -Filter 'sdkmanager.bat' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName -First 1
}

function Wait-ForDocker {
    Write-Host 'Waiting for Docker Desktop engine...' -ForegroundColor DarkCyan
    for ($attempt = 1; $attempt -le 36; $attempt++) {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $null = docker info 2>$null
        $dockerExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        if ($dockerExitCode -eq 0) {
            Write-Ok 'Docker engine is ready'
            return
        }
        Start-Sleep -Seconds 5
    }
    throw 'Docker Desktop is installed but its engine is not ready. Open Docker Desktop and run this script again.'
}

function Wait-ForApi {
    Write-Host 'Waiting for the local API...' -ForegroundColor DarkCyan
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri 'http://localhost:3000/health' -TimeoutSec 3
            if ($response.success -eq $true) {
                Write-Ok 'API health check passed'
                return
            }
        } catch {
            # The backend process may still be starting.
        }
        Start-Sleep -Seconds 2
    }
    throw 'The API did not answer on http://localhost:3000/health. Check the backend terminal for errors.'
}

Write-Host 'CSW430 local demo setup' -ForegroundColor White
Write-Host "Repository: $repoRoot"

Write-Step 'Checking required desktop tools'
Ensure-Command 'git' 'Git.Git' 'Git'
Ensure-Command 'node' 'OpenJS.NodeJS.LTS' 'Node.js'
Ensure-Command 'npm' 'OpenJS.NodeJS.LTS' 'npm'
Ensure-Command 'docker' 'Docker.DockerDesktop' 'Docker Desktop'
Ensure-Flutter
Ensure-Command 'java' 'Microsoft.OpenJDK.17' 'Java/JDK'

$androidStudio = Find-AndroidStudio
if (-not $androidStudio) {
    [void](Install-WingetPackage 'Google.AndroidStudio' 'Android Studio')
    $androidStudio = Find-AndroidStudio
}
if ($androidStudio) {
    Write-Ok "Android Studio detected: $androidStudio"
} else {
    Write-Warn 'Android Studio was not found. Install it manually, including Android SDK, Platform Tools, Emulator, and an Android Virtual Device.'
}

Write-Step 'Checking Flutter Android tooling'
& flutter doctor -v
if ($LASTEXITCODE -ne 0) {
    Write-Warn 'Flutter doctor reported issues. The script will continue, but Android Studio SDK setup may need to be completed manually.'
}

if (-not (Has-Command 'adb')) {
    Write-Warn 'adb is not on PATH. In Android Studio, install Android SDK Platform-Tools and add its platform-tools folder to PATH.'
} else {
    Write-Ok 'Android Debug Bridge (adb) detected'
}

Write-Step 'Creating local backend configuration'
$envPath = Join-Path $backendPath '.env'
if (-not (Test-Path $envPath)) {
    $randomBytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
    $jwtSecret = [Convert]::ToBase64String($randomBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
    @"
PORT=3000
DATABASE_URL=postgresql://csw430:csw430_local_password@localhost:5433/csw430_project
JWT_SECRET=$jwtSecret
"@ | Set-Content -LiteralPath $envPath -Encoding utf8
    Write-Ok 'Created backend/.env with a generated local JWT secret'
} else {
    Write-Ok 'backend/.env already exists; leaving it unchanged'
}

Write-Step 'Installing project dependencies'
Push-Location $backendPath
try {
    if (-not (Test-Path (Join-Path $backendPath 'node_modules'))) {
        npm ci
    } else {
        Write-Ok 'Node dependencies already installed'
    }
} finally {
    Pop-Location
}

Push-Location $mobilePath
try {
    flutter pub get
} finally {
    Pop-Location
}

Write-Step 'Starting PostgreSQL in Docker'
Push-Location $repoRoot
try {
    $dockerDesktop = @(
        (Join-Path ${env:ProgramFiles} 'Docker\Docker\Docker Desktop.exe'),
        (Join-Path ${env:LOCALAPPDATA} 'Docker\Docker Desktop.exe')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($dockerDesktop) {
        Start-Process -FilePath $dockerDesktop -ErrorAction SilentlyContinue | Out-Null
    }
    Wait-ForDocker
    docker compose up -d
    Write-Ok 'PostgreSQL container started'
} finally {
    Pop-Location
}

Write-Step 'Starting Node.js API'
$portCheck = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if (-not $portCheck) {
    Start-Process powershell.exe -ArgumentList @(
        '-NoExit',
        '-ExecutionPolicy', 'Bypass',
        '-Command', "Set-Location -LiteralPath '$backendPath'; npm start"
    ) | Out-Null
    Write-Ok 'Backend terminal opened'
} else {
    Write-Ok 'Port 3000 is already in use; assuming the API is already running'
}
Wait-ForApi

Write-Step 'Checking Android device or emulator'
$deviceOutput = (& flutter devices 2>&1 | Out-String)
Write-Host $deviceOutput
$deviceLines = $deviceOutput -split "`r?`n"
$hasAndroidDevice = @($deviceLines | Where-Object {
    $_ -match '•' -and $_ -match '(?i)android|emulator'
}).Count -gt 0

if (-not $hasAndroidDevice -and -not $NoApp) {
    $emulatorPath = Get-Command 'emulator' -ErrorAction SilentlyContinue
    if ($emulatorPath) {
        $avdName = (& $emulatorPath.Source -list-avds 2>$null | Where-Object { $_.Trim() } | Select-Object -First 1)
        if ($avdName) {
            Write-Host "Starting Android Virtual Device: $avdName" -ForegroundColor DarkCyan
            Start-Process -FilePath $emulatorPath.Source -ArgumentList @('-avd', $avdName.Trim(), '-netdelay', 'none', '-netspeed', 'full') | Out-Null
            for ($attempt = 1; $attempt -le 30; $attempt++) {
                Start-Sleep -Seconds 2
                $deviceOutput = (& flutter devices 2>&1 | Out-String)
                $deviceLines = $deviceOutput -split "`r?`n"
                $hasAndroidDevice = @($deviceLines | Where-Object {
                    $_ -match '•' -and $_ -match '(?i)android|emulator'
                }).Count -gt 0
                if ($hasAndroidDevice) { break }
            }
        }
    }
}

if ($hasAndroidDevice -and -not $NoApp) {
    Write-Step 'Starting Flutter app'
    Push-Location $mobilePath
    try {
        flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
    } finally {
        Pop-Location
    }
} elseif (-not $hasAndroidDevice) {
    Write-Warn 'No Android device/emulator is currently available.'
    Write-Host 'Open Android Studio Device Manager, start an emulator, then run:' -ForegroundColor Yellow
    Write-Host "  cd `"$mobilePath`""
    Write-Host '  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000'
}

Write-Host "`nDemo setup completed. Git commit and push were not performed." -ForegroundColor Green
