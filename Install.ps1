# --- ส่วนที่ทำให้รันใน Background แม้จะปิดหน้าต่าง ---
if ($args[0] -ne "hidden") {
    # สั่งให้ PowerShell เปิดตัวเองใหม่แบบซ่อนหน้าต่าง
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" hidden" -WindowStyle Hidden
    exit
}

# --- ตั้งค่าตัวแปร ---
$ProcessName = "HD-Player"
$DllPath = "C:\Program Files\BlueStacks_nxt\BstkVVM.dll"

# --- โหลดฟังก์ชัน C# สำหรับ Injection และดักจับปุ่ม ---
$Source = @"
using System;
using System.Runtime.InteropServices;

public class Injector {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@

if (-not ([System.Management.Automation.PSTypeName]"Injector").Type) {
    Add-Type -TypeDefinition $Source
}

# --- ฟังก์ชันสำหรับฉีด DLL ---
function Do-Injection {
    $TargetProcess = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($TargetProcess) {
        try {
            $hProcess = [Injector]::OpenProcess(0x1F0FFF, $false, $TargetProcess.Id)
            $DllPathBytes = [System.Text.Encoding]::ASCII.GetBytes($DllPath + "`0")
            $AllocatedMemory = [Injector]::VirtualAllocEx($hProcess, [IntPtr]::Zero, [uint32]$DllPathBytes.Length, 0x3000, 0x40)
            $BytesWritten = [IntPtr]::Zero
            [Injector]::WriteProcessMemory($hProcess, $AllocatedMemory, $DllPathBytes, [uint32]$DllPathBytes.Length, [ref] $BytesWritten)
            $Kernel32Handle = [Injector]::GetModuleHandle("kernel32.dll")
            $LoadLibraryAddr = [Injector]::GetProcAddress($Kernel32Handle, "LoadLibraryA")
            [Injector]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $LoadLibraryAddr, $AllocatedMemory, 0, [IntPtr]::Zero)
            return $true
        } catch { return $false }
    }
    return $false
}

# พยายามฉีด DLL ครั้งแรก
$Injected = Do-Injection
$wshell = New-Object -ComObject WScript.Shell
$F5_Key = 0x74

# --- Loop ทำงานตลอดเวลาใน Background ---
while ($true) {
    $CheckProc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    
    if ($CheckProc) {
        # ถ้ายังไม่ได้ฉีด DLL ให้ฉีด
        if (-not $Injected) { $Injected = Do-Injection }

        # เช็คการกดปุ่ม F5
        $KeyState = [Injector]::GetAsyncKeyState($F5_Key)
        if ($KeyState -band 0x8000) {
            # เมื่อกด F5: รอ 30 วินาที
            Start-Sleep -Seconds 30
            
            # --- ส่วนแจ้งเตือนแบบหน้าต่าง (ไม่มีเสียง) ---
            # ตัวเลข 64 คือไอคอน Information, เลข 0 คือต้องกดตกลงถึงจะหายไป
            $wshell.Popup("ครบ 30 วินาทีแล้ว!", 0, "การแจ้งเตือน", 64) | Out-Null
        }
    } else {
        $Injected = $false
    }
    
    Start-Sleep -Milliseconds 150
}
