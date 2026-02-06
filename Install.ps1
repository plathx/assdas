# ==========================================
# ส่วนที่ 1: ตรวจสอบและซ่อนหน้าต่าง (Run in Background)
# ==========================================
Param([switch]$RunHidden)

if (-not $RunHidden) {
    # ถ้ายังไม่ได้รันแบบซ่อน ให้เรียกตัวเองใหม่แบบซ่อนหน้าต่าง
    $ScriptPath = $MyInvocation.MyCommand.Path
    
    # ตรวจสอบว่าไฟล์ถูกบันทึกหรือยัง
    if (-not $ScriptPath) {
        Write-Host "กรุณาบันทึกสคริปต์เป็นไฟล์ .ps1 ก่อนรัน" -ForegroundColor Red
        Read-Host "กด Enter เพื่อออก..."
        exit
    }

    # รัน PowerShell ใหม่แบบ Hidden Window
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`" -RunHidden" -WindowStyle Hidden
    
    # ปิดหน้าต่างปัจจุบัน
    Exit
}

# ==========================================
# ส่วนที่ 2: โค้ดหลักของคุณ (Main Logic)
# ==========================================

$ProcessName = "HD-Player"
$DllPath = "C:\Program Files\BlueStacks_nxt\BstkVVM.dll"

# หมายเหตุ: เมื่อรันแบบ Background คำสั่ง Write-Host จะไม่แสดงผลให้เห็น
# แต่สคริปต์จะยังทำงานอยู่

if (-not (Test-Path $DllPath)) {
    # ในโหมด Background อาจต้องเปลี่ยนการแจ้งเตือน Error เป็น Popup หรือ Log file แทน
    return
}

$Source = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

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

    public const uint PROCESS_ALL_ACCESS = 0x1F0FFF;
    public const uint MEM_COMMIT = 0x1000;
    public const uint MEM_RESERVE = 0x2000;
    public const uint PAGE_EXECUTE_READWRITE = 0x40;
}
"@

if (-not ([System.Management.Automation.PSTypeName]"Injector").Type) {
    Add-Type -TypeDefinition $Source
}

# พยายามหา Process (ถ้าไม่เจอสคริปต์จะจบการทำงานทันที)
$TargetProcess = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
if (-not $TargetProcess) {
    # ถ้าหาไม่เจอจะหยุดทำงาน (เนื่องจากไม่มีหน้าต่างให้แจ้งเตือน)
    return
}

$TargetPID = $TargetProcess.Id

try {
    $hProcess = [Injector]::OpenProcess([Injector]::PROCESS_ALL_ACCESS, $false, $TargetPID)
    if ($hProcess -eq [IntPtr]::Zero) { throw "Could not open process handle." }

    $DllPathBytes = [System.Text.Encoding]::ASCII.GetBytes($DllPath + "`0")
    $AllocatedMemory = [Injector]::VirtualAllocEx($hProcess, [IntPtr]::Zero, [uint32]$DllPathBytes.Length, [Injector]::MEM_COMMIT -bor [Injector]::MEM_RESERVE, [Injector]::PAGE_EXECUTE_READWRITE)
    if ($AllocatedMemory -eq [IntPtr]::Zero) { throw "Could not allocate memory." }

    $BytesWritten = [IntPtr]::Zero
    $Result = [Injector]::WriteProcessMemory($hProcess, $AllocatedMemory, $DllPathBytes, [uint32]$DllPathBytes.Length, [ref] $BytesWritten)
    if (-not $Result) { throw "Could not write to memory." }

    $Kernel32Handle = [Injector]::GetModuleHandle("kernel32.dll")
    $LoadLibraryAddr = [Injector]::GetProcAddress($Kernel32Handle, "LoadLibraryA")

    $ThreadHandle = [Injector]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $LoadLibraryAddr, $AllocatedMemory, 0, [IntPtr]::Zero)

    # DLL Injected Successfully (ทำเงียบๆ ใน Background)
}
catch {
    # หากเกิด Error ใน Background มันจะหยุดทำงานเงียบๆ
    return
}

# ==========================================
# ส่วนที่ 3: Monitoring Loop (ทำงานตลอดเวลา)
# ==========================================

$F5_Key = 0x74

while ($true) {
    # ตรวจสอบว่า Process ยังอยู่ไหม ถ้าโปรแกรมปิดไปแล้ว สคริปต์ควรจบการทำงาน
    $CheckProc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    
    if ($CheckProc) {
        $KeyState = [Injector]::GetAsyncKeyState($F5_Key)
        if ($KeyState -band 0x8000) {
            
            # หน่วงเวลา 30 วินาที
            Start-Sleep -Seconds 30
            
            # แสดง Popup แจ้งเตือน (Popup นี้จะเด้งขึ้นมาแม้ไม่มีหน้าต่าง Console)
            $wshell = New-Object -ComObject WScript.Shell
            $wshell.Popup("ครบ 30 วินาทีแล้ว!", 0, "การแจ้งเตือนจาก Background Script", 64) | Out-Null
        }
    } else {
        # ถ้าโปรแกรม HD-Player ปิดไปแล้ว ให้ปิดสคริปต์ตามไปด้วยเพื่อไม่ให้กินทรัพยากร
        return
    }
    
    # ลดภาระ CPU
    Start-Sleep -Milliseconds 100
}
