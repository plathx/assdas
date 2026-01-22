# 1. กำหนดเนื้อหาโค้ด Batch file ลงในตัวแปร (ใช้รูปแบบ Here-String เพื่อเก็บอักขระพิเศษได้ครบ)
$batContent = @'
@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: ตั้งค่าเบื้องต้น
:: ============================================================
cd /d "%~dp0"
set "LOGFILE=%~dp0Install_Log.txt"
set "TOTAL_STEPS=20"
set "CURRENT_STEP=0"

:: เคลียร์ไฟล์ Log เก่า (ถ้ามี)
if exist "%LOGFILE%" del "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"
echo  Start Installation Log: %date% %time% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

:: ฟังก์ชั่นปรับหน้าจอ
mode con: cols=100 lines=30
color 0A

:: ตรวจสอบสิทธิ์ Admin
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running as Administrator.
) else (
    echo [ERROR] Please right-click and "Run as administrator".
    pause
    exit
)

:: ============================================================
:: เริ่มการทำงาน
:: ============================================================

:: ------------------------------------------------------------
:: จำเป็น 1: Install Winget (AppInstaller)
:: ------------------------------------------------------------
call :UpdateProgress "Installing Microsoft AppInstaller (Winget)"
powershell.exe -Command "$url = 'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'; $outpath = '$env:TEMP\AppInstaller.msixbundle'; Write-Host 'Downloading...'; Invoke-WebRequest -Uri $url -OutFile $outpath; Write-Host 'Installing...'; Add-AppxPackage -Path $outpath; Remove-Item $outpath" >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: จำเป็น 2: Install Brave Browser
:: ------------------------------------------------------------
call :UpdateProgress "Installing Brave Browser"
winget install Brave.Brave --silent --accept-package-agreements --accept-source-agreements --force >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: จำเป็น 3: Set Default Browser
:: ------------------------------------------------------------
call :UpdateProgress "Opening Default Apps Settings (Please set Brave manually)"
:: หมายเหตุ: Windows ไม่อนุญาตให้ Script เปลี่ยนค่า Default โดยอัตโนมัติ ต้องให้ user กดเอง
echo [INFO] Opening Windows Settings. Please select Brave as your Web Browser. >> "%LOGFILE%"
start ms-settings:defaultapps

:: ------------------------------------------------------------
:: 1. .NET Desktop Runtime (Loop 6-10)
:: ------------------------------------------------------------
:: นับเป็น 5 Steps ย่อย หรือรวบเป็น 1 ก็ได้ แต่เพื่อให้ละเอียดจะวนลูปเรียก
for %%v in (6 7 8 9 10) do (
    call :UpdateProgress "Installing Microsoft .NET Desktop Runtime %%v"
    winget install --id Microsoft.DotNet.DesktopRuntime.%%v --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1
)

:: ------------------------------------------------------------
:: 2. Microsoft DirectX
:: ------------------------------------------------------------
call :UpdateProgress "Installing Microsoft DirectX"
winget install Microsoft.DirectX --silent --accept-package-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 3. VC++ Redistributable All-in-One
:: ------------------------------------------------------------
call :UpdateProgress "Installing VC++ Redistributable All-in-One"
winget install IsidroG.VCRedistVisualCPlusPlusAllInOne --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 4. OpenJDK 21
:: ------------------------------------------------------------
call :UpdateProgress "Installing Microsoft OpenJDK 21"
winget install Microsoft.OpenJDK.21 --silent --accept-package-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 5. CapCut
:: ------------------------------------------------------------
call :UpdateProgress "Installing ByteDance CapCut"
winget install ByteDance.CapCut --silent --accept-package-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 6. Discord (Standard)
:: ------------------------------------------------------------
call :UpdateProgress "Installing Discord (Standard)"
winget install Discord.Discord --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 7. Discord (PTB)
:: ------------------------------------------------------------
call :UpdateProgress "Installing Discord (PTB)"
winget install Discord.Discord.PTB --silent --accept-package-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 8. Discord (Canary)
:: ------------------------------------------------------------
call :UpdateProgress "Installing Discord (Canary)"
winget install Discord.Discord.Canary --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 9. Parsec
:: ------------------------------------------------------------
call :UpdateProgress "Installing Parsec"
winget install Parsec.Parsec --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 10. Spotify (SpotX) & Clean Cache
:: ------------------------------------------------------------
call :UpdateProgress "Running SpotX (Spotify Mod) & Cleaning Cache"
echo Running SpotX script... >> "%LOGFILE%"
:: รัน SpotX (ลบคำสั่ง exit ของเดิมออกเพื่อให้สคริปต์ไปต่อ)
powershell.exe -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = 'Tls12'; $scriptContent = (Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/SpotX-Official/SpotX/refs/heads/main/run.ps1').Content; Invoke-Expression -Command ('& {' + $scriptContent + '} -confirm_uninstall_ms_spoti -confirm_spoti_recomended_over -podcasts_off -block_update_on -start_spoti -new_theme -adsections_off -lyrics_stat spotify')" >> "%LOGFILE%" 2>&1

echo Copying CleanCache files... >> "%LOGFILE%"
:: ตรวจสอบว่ามีโฟลเดอร์ต้นทางไหม
if exist "%~dp0CleanCache\SpotifyCleanCache.bat" (
    xcopy /h /c /k /Y "%~dp0CleanCache\SpotifyCleanCache.bat" "%appdata%\Spotify\" >> "%LOGFILE%" 2>&1
) else (
    echo [WARNING] SpotifyCleanCache.bat not found >> "%LOGFILE%"
)

if exist "%~dp0CleanCache\CleanCache.lnk" (
    xcopy /h /c /k /Y "%~dp0CleanCache\CleanCache.lnk" "%appdata%\Microsoft\Windows\Start Menu\Programs\" >> "%LOGFILE%" 2>&1
) else (
    echo [WARNING] CleanCache.lnk not found >> "%LOGFILE%"
)

:: ------------------------------------------------------------
:: 11. Steam
:: ------------------------------------------------------------
call :UpdateProgress "Installing Valve Steam"
winget install Valve.Steam --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 12. Clownfish Voice Changer
:: ------------------------------------------------------------
call :UpdateProgress "Installing Clownfish Voice Changer"
winget install SharkLabs.ClownfishVoiceChanger --silent --accept-package-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 13. X-Mouse Button Control
:: ------------------------------------------------------------
call :UpdateProgress "Installing X-Mouse Button Control"
winget install Highrez.XMouseButtonControl --silent --accept-package-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 14. IoT Driver (v215)
:: ------------------------------------------------------------
call :UpdateProgress "Downloading & Installing IoT Driver v215"
powershell.exe -Command "$url = 'https://news.rongyuan.tech/iot_driver/win/iot_v215.exe'; $outpath = '$env:TEMP\iot_v215.exe'; Write-Host 'Downloading Driver...'; Invoke-WebRequest -Uri $url -OutFile $outpath; Write-Host 'Installing Driver...'; Start-Process -FilePath $outpath -ArgumentList '/S' -Wait; Remove-Item $outpath" >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 15. SuperF4
:: ------------------------------------------------------------
call :UpdateProgress "Installing SuperF4"
winget install stefansundin.SuperF4 --silent --accept-package-agreements >> "%LOGFILE%" 2>&1

:: ------------------------------------------------------------
:: 16. AMD Radeon Software
:: ------------------------------------------------------------
call :UpdateProgress "Installing AMD Radeon Software"
winget install AMD.RadeonSoftware --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1


:: ============================================================
:: เสร็จสิ้น
:: ============================================================
set "CURRENT_STEP=%TOTAL_STEPS%"
cls
echo ============================================================
echo.
echo      INSTALLATION COMPLETED! (100%%)
echo.
echo      Please check "%LOGFILE%" for details/errors.
echo.
echo ============================================================
echo Finished at %date% %time% >> "%LOGFILE%"
pause
exit


:: ============================================================
:: ส่วนของฟังก์ชั่น (Subroutine)
:: ============================================================
:UpdateProgress
set /a CURRENT_STEP+=1
set /a PERCENT=(CURRENT_STEP*100)/TOTAL_STEPS
cls
echo ============================================================
echo  AUTO INSTALLER SCRIPT
echo ============================================================
echo.
echo  Progress: [ %PERCENT%%% ]  (Step %CURRENT_STEP% of %TOTAL_STEPS%)
echo.
echo  Now Processing: %~1
echo.
echo  (Please wait... Output is being logged to file)
echo.
echo ============================================================
exit /b
'@

# 2. กำหนด Path ที่จะบันทึกไฟล์ (โฟลเดอร์ Downloads)
$savePath = "$env:USERPROFILE\Downloads\AutoInstall_Setup.bat"

# 3. สร้างไฟล์ .bat (ใช้ Encoding UTF8 เพื่อรองรับภาษาไทยใน Comment)
$batContent | Out-File -FilePath $savePath -Encoding utf8

# 4. แสดงผลลัพธ์
Write-Host "---------------------------------------------------" -ForegroundColor Cyan
Write-Host "สร้างไฟล์สำเร็จแล้ว!" -ForegroundColor Green
Write-Host "ตำแหน่งไฟล์: $savePath" -ForegroundColor Yellow
Write-Host "อย่าลืมคลิกขวาที่ไฟล์แล้วเลือก 'Run as administrator'" -ForegroundColor Red
Write-Host "---------------------------------------------------" -ForegroundColor Cyan
