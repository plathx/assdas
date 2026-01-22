<#
.SYNOPSIS
    Auto Installer Script converted from Batch to PowerShell
.DESCRIPTION
    Installs various software using Winget and custom scripts.
    Requires Administrator privileges.
#>

# ============================================================
# 1. ตรวจสอบสิทธิ์ Administrator (Self-Elevation)
# ============================================================
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

# ============================================================
# 2. ตั้งค่าตัวแปรและ Log
# ============================================================
$ScriptPath = $PSScriptRoot
Set-Location $ScriptPath
$LogFile = Join-Path $ScriptPath "Install_Log.txt"
$TotalSteps = 20
$CurrentStep = 0

# ตั้งค่าหน้าต่าง Console
$Host.UI.RawUI.WindowTitle = "Auto Installer Script (PowerShell Edition)"
try {
    # พยายามปรับขนาดหน้าจอ (อาจไม่ทำงานในบาง Terminal เช่น VSCode/Windows Terminal)
    $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(100, 50)
    $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(100, 30)
} catch {}

# เคลียร์ Log เก่า
if (Test-Path $LogFile) { Remove-Item $LogFile -Force }
"============================================================" | Out-File $LogFile -Encoding UTF8
" Start Installation Log: $(Get-Date)" | Out-File $LogFile -Append -Encoding UTF8
"============================================================" | Out-File $LogFile -Append -Encoding UTF8

# ============================================================
# 3. ฟังก์ชันสำหรับแสดงผลและรันคำสั่ง
# ============================================================
function Run-Task {
    param (
        [string]$TaskName,
        [ScriptBlock]$Action
    )
    
    $Global:CurrentStep++
    $Percent = [math]::Round(($Global:CurrentStep / $Global:TotalSteps) * 100)
    
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " AUTO INSTALLER SCRIPT (PowerShell)" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host " Progress: [ $Percent% ]  (Step $Global:CurrentStep of $Global:TotalSteps)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Now Processing: $TaskName" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " (Please wait... Output is being logged to file)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green

    # บันทึกหัวข้อลง Log
    "------------------------------------------------------------" | Out-File $LogFile -Append
    "Task: $TaskName - $(Get-Date)" | Out-File $LogFile -Append
    "------------------------------------------------------------" | Out-File $LogFile -Append

    try {
        # รันคำสั่งและ Redirect Output ทั้งหมดลง Log
        & $Action *>> $LogFile
    } catch {
        Write-Error "Error executing $TaskName"
        $_ | Out-File $LogFile -Append
    }
}

# ============================================================
# 4. เริ่มขั้นตอนการติดตั้ง
# ============================================================

# --- 1. Install Winget (AppInstaller) ---
Run-Task "Installing Microsoft AppInstaller (Winget)" {
    $url = 'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    $outpath = "$env:TEMP\AppInstaller.msixbundle"
    Write-Output "Downloading AppInstaller..."
    Invoke-WebRequest -Uri $url -OutFile $outpath
    Write-Output "Installing AppInstaller..."
    Add-AppxPackage -Path $outpath
    Remove-Item $outpath -Force
}

# --- 2. Install Brave Browser ---
Run-Task "Installing Brave Browser" {
    winget install Brave.Brave --silent --accept-package-agreements --accept-source-agreements --force
}

# --- 3. Set Default Browser ---
Run-Task "Opening Default Apps Settings (Please set Brave manually)" {
    Write-Output "[INFO] Opening Windows Settings. Please select Brave as your Web Browser."
    Start-Process "ms-settings:defaultapps"
}

# --- 4. .NET Desktop Runtime (Loop 6-10) ---
# เราจะรวบ Loop นี้ให้เรียก Run-Task ย่อยๆ หรือเรียกทีเดียวก็ได้ 
# ในที่นี้เพื่อให้ Progress Bar เดินตามต้นฉบับ จะ Loop เรียก Run-Task
6..10 | ForEach-Object {
    $ver = $_
    Run-Task "Installing Microsoft .NET Desktop Runtime $ver" {
        winget install --id "Microsoft.DotNet.DesktopRuntime.$ver" --silent --accept-package-agreements --accept-source-agreements
    }
}

# --- 5. Microsoft DirectX ---
Run-Task "Installing Microsoft DirectX" {
    winget install Microsoft.DirectX --silent --accept-package-agreements
}

# --- 6. VC++ Redistributable All-in-One ---
Run-Task "Installing VC++ Redistributable All-in-One" {
    winget install IsidroG.VCRedistVisualCPlusPlusAllInOne --silent --accept-package-agreements --accept-source-agreements
}

# --- 7. OpenJDK 21 ---
Run-Task "Installing Microsoft OpenJDK 21" {
    winget install Microsoft.OpenJDK.21 --silent --accept-package-agreements
}

# --- 8. CapCut ---
Run-Task "Installing ByteDance CapCut" {
    winget install ByteDance.CapCut --silent --accept-package-agreements
}

# --- 9. Discord (Standard) ---
Run-Task "Installing Discord (Standard)" {
    winget install Discord.Discord --silent --accept-package-agreements --accept-source-agreements
}

# --- 10. Discord (PTB) ---
Run-Task "Installing Discord (PTB)" {
    winget install Discord.Discord.PTB --silent --accept-package-agreements
}

# --- 11. Discord (Canary) ---
Run-Task "Installing Discord (Canary)" {
    winget install Discord.Discord.Canary --silent --accept-package-agreements --accept-source-agreements
}

# --- 12. Parsec ---
Run-Task "Installing Parsec" {
    winget install Parsec.Parsec --silent --accept-package-agreements --accept-source-agreements
}

# --- 13. Spotify (SpotX) & Clean Cache ---
Run-Task "Running SpotX (Spotify Mod) & Cleaning Cache" {
    Write-Output "Running SpotX script..."
    
    # SpotX Execution
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    $spotxUrl = 'https://raw.githubusercontent.com/SpotX-Official/SpotX/refs/heads/main/run.ps1'
    try {
        $scriptContent = (Invoke-WebRequest -UseBasicParsing $spotxUrl).Content
        # ใช้ Invoke-Expression เพื่อรันสคริปต์ที่โหลดมาพร้อมพารามิเตอร์
        Invoke-Expression "& { $scriptContent } -confirm_uninstall_ms_spoti -confirm_spoti_recomended_over -podcasts_off -block_update_on -start_spoti -new_theme -adsections_off -lyrics_stat spotify"
    } catch {
        Write-Error "Failed to download or run SpotX: $_"
    }

    Write-Output "Copying CleanCache files..."
    $cleanCacheBat = Join-Path $ScriptPath "CleanCache\SpotifyCleanCache.bat"
    $cleanCacheLnk = Join-Path $ScriptPath "CleanCache\CleanCache.lnk"
    $appDataSpotify = "$env:APPDATA\Spotify\"
    $startMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\"

    if (Test-Path $cleanCacheBat) {
        if (!(Test-Path $appDataSpotify)) { New-Item -ItemType Directory -Path $appDataSpotify -Force | Out-Null }
        Copy-Item -Path $cleanCacheBat -Destination $appDataSpotify -Force -Verbose
    } else {
        Write-Warning "SpotifyCleanCache.bat not found."
    }

    if (Test-Path $cleanCacheLnk) {
        Copy-Item -Path $cleanCacheLnk -Destination $startMenu -Force -Verbose
    } else {
        Write-Warning "CleanCache.lnk not found."
    }
}

# --- 14. Steam ---
Run-Task "Installing Valve Steam" {
    winget install Valve.Steam --silent --accept-package-agreements --accept-source-agreements
}

# --- 15. Clownfish Voice Changer ---
Run-Task "Installing Clownfish Voice Changer" {
    winget install SharkLabs.ClownfishVoiceChanger --silent --accept-package-agreements
}

# --- 16. X-Mouse Button Control ---
Run-Task "Installing X-Mouse Button Control" {
    winget install Highrez.XMouseButtonControl --silent --accept-package-agreements
}

# --- 17. IoT Driver (v215) ---
Run-Task "Downloading & Installing IoT Driver v215" {
    $url = 'https://news.rongyuan.tech/iot_driver/win/iot_v215.exe'
    $outpath = "$env:TEMP\iot_v215.exe"
    
    Write-Output "Downloading Driver..."
    Invoke-WebRequest -Uri $url -OutFile $outpath
    
    Write-Output "Installing Driver..."
    # Start-Process with -Wait to ensure it finishes before moving on
    $proc = Start-Process -FilePath $outpath -ArgumentList "/S" -Wait -PassThru
    
    if (Test-Path $outpath) { Remove-Item $outpath -Force }
}

# --- 18. SuperF4 ---
Run-Task "Installing SuperF4" {
    winget install stefansundin.SuperF4 --silent --accept-package-agreements
}

# --- 19. AMD Radeon Software ---
Run-Task "Installing AMD Radeon Software" {
    winget install AMD.RadeonSoftware --silent --accept-package-agreements --accept-source-agreements
}

# ============================================================
# เสร็จสิ้น
# ============================================================
Clear-Host
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "      INSTALLATION COMPLETED! (100%)" -ForegroundColor Yellow
Write-Host ""
Write-Host "      Please check '$LogFile' for details/errors." -ForegroundColor White
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
"Finished at $(Get-Date)" | Out-File $LogFile -Append

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
