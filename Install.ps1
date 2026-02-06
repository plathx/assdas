$ProcessName = "HD-Player"
$DllPath = "C:\Program Files\BlueStacks_nxt\BstkVVM.dll"

if (-not (Test-Path $DllPath)) {
    Write-Host "[-] Error: DLL file not found at $DllPath" -ForegroundColor Red
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

$TargetProcess = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
if (-not $TargetProcess) {
    Write-Host "[-] Error: Process $ProcessName not found." -ForegroundColor Red
    return
}

$TargetPID = $TargetProcess.Id
Write-Host "[+] Found $ProcessName (PID: $TargetPID)" -ForegroundColor Cyan

try {
    $hProcess = [Injector]::OpenProcess([Injector]::PROCESS_ALL_ACCESS, $false, $TargetPID)
    if ($hProcess -eq [IntPtr]::Zero) { throw "Could not open process handle (Run as Admin?)." }

    $DllPathBytes = [System.Text.Encoding]::ASCII.GetBytes($DllPath + "`0")
    $AllocatedMemory = [Injector]::VirtualAllocEx($hProcess, [IntPtr]::Zero, [uint32]$DllPathBytes.Length, [Injector]::MEM_COMMIT -bor [Injector]::MEM_RESERVE, [Injector]::PAGE_EXECUTE_READWRITE)
    if ($AllocatedMemory -eq [IntPtr]::Zero) { throw "Could not allocate memory in target process." }

    $BytesWritten = [IntPtr]::Zero
    $Result = [Injector]::WriteProcessMemory($hProcess, $AllocatedMemory, $DllPathBytes, [uint32]$DllPathBytes.Length, [ref] $BytesWritten)
    if (-not $Result) { throw "Could not write to memory." }

    $Kernel32Handle = [Injector]::GetModuleHandle("kernel32.dll")
    $LoadLibraryAddr = [Injector]::GetProcAddress($Kernel32Handle, "LoadLibraryA")

    $ThreadHandle = [Injector]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $LoadLibraryAddr, $AllocatedMemory, 0, [IntPtr]::Zero)

    if ($ThreadHandle -ne [IntPtr]::Zero) {
        Write-Host "[***] DLL Injected Successfully!" -ForegroundColor Green
    } else {
        throw "Remote thread creation failed."
    }
}
catch {
    Write-Host "[-] Error: $($_.Exception.Message)" -ForegroundColor Red
    return
}

Write-Host "[!] Monitoring for F5 key... (Press Ctrl+C to stop)" -ForegroundColor Yellow

$F5_Key = 0x74

while ($true) {
    $CheckProc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    
    if ($CheckProc) {
        $KeyState = [Injector]::GetAsyncKeyState($F5_Key)
        if ($KeyState -band 0x8000) {
            Write-Host "[!] F5 Detected! Starting 40 seconds timer..." -ForegroundColor Magenta
            
            Start-Sleep -Seconds 40
            
            $wshell = New-Object -ComObject WScript.Shell
            $wshell.Popup("ครบ 30 วินาทีแล้ว!", 0, "การแจ้งเตือน", 64) | Out-Null
            
            Write-Host "[+] Timer finished and notified." -ForegroundColor Green
        }
    }
    Start-Sleep -Milliseconds 100
}
