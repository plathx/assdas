if ($args[0] -ne "hidden") {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" hidden" -WindowStyle Hidden
    Write-Host "[+] Starting in background mode..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    exit
}


$ProcessName = "HD-Player"
$DllPath = "C:\Program Files\BlueStacks_nxt\BstkVVM.dll"

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

    public const uint PROCESS_ALL_ACCESS = 0x1F0FFF;
    public const uint MEM_COMMIT = 0x1000;
    public const uint MEM_RESERVE = 0x2000;
    public const uint PAGE_EXECUTE_READWRITE = 0x40;
}
"@

Add-Type -TypeDefinition $Source

function Start-Injection {
    $TargetProcess = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($TargetProcess) {
        $TargetPID = $TargetProcess.Id
        try {
            $hProcess = [Injector]::OpenProcess([Injector]::PROCESS_ALL_ACCESS, $false, $TargetPID)
            $DllPathBytes = [System.Text.Encoding]::ASCII.GetBytes($DllPath + "`0")
            $AllocatedMemory = [Injector]::VirtualAllocEx($hProcess, [IntPtr]::Zero, [uint32]$DllPathBytes.Length, 0x3000, 0x40)
            $BytesWritten = [IntPtr]::Zero
            [Injector]::WriteProcessMemory($hProcess, $AllocatedMemory, $DllPathBytes, [uint32]$DllPathBytes.Length, [ref] $BytesWritten)
            $Kernel32Handle = [Injector]::GetModuleHandle("kernel32.dll")
            $LoadLibraryAddr = [Injector]::GetProcAddress($Kernel32Handle, "LoadLibraryA")
            [Injector]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $LoadLibraryAddr, $AllocatedMemory, 0, [IntPtr]::Zero)
        } catch {}
    }
}

Start-Injection

$F5_Key = 0x74

while ($true) {
    $CheckProc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    
    if ($CheckProc) {
        $KeyState = [Injector]::GetAsyncKeyState($F5_Key)
        if ($KeyState -band 0x8000) {
            Start-Sleep -Seconds 30
            
            [Console]::Beep(1000, 600) 
        }
    }
    
    Start-Sleep -Milliseconds 150
}
