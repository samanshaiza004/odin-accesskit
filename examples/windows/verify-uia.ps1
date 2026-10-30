param(
    [Parameter(Mandatory = $true)]
    [string]$Executable
)

# Run in Windows PowerShell 5.1 (UIAutomationClient is part of .NET Framework).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class AccessKitExampleTestNative {
    private delegate bool EnumWindowProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowProc callback, IntPtr data);
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    public static IntPtr FindWindowForProcess(int processId) {
        IntPtr result = IntPtr.Zero;
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            if (pid != processId) return true;
            result = hwnd;
            return false;
        }, IntPtr.Zero);
        return result;
    }
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hwnd, uint msg, UIntPtr wparam, IntPtr lparam);
}
'@

function Assert-Example($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Wait-Example([scriptblock]$Predicate, [string]$Message) {
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        if (& $Predicate) { return }
        Start-Sleep -Milliseconds 25
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Message"
}

$path = (Resolve-Path -LiteralPath $Executable).Path
$process = Start-Process -FilePath $path -WindowStyle Hidden -PassThru
$root = $null
try {
    Wait-Example {
        $process.Refresh()
        -not $process.HasExited -and [AccessKitExampleTestNative]::FindWindowForProcess($process.Id) -ne [IntPtr]::Zero
    } 'native window creation'
    $hwnd = [AccessKitExampleTestNative]::FindWindowForProcess($process.Id)
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    $descendants = [System.Windows.Automation.TreeScope]::Descendants
    $buttonCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Button)
    $fieldCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Edit)
    $button = $root.FindFirst($descendants, $buttonCondition)
    $field = $root.FindFirst($descendants, $fieldCondition)
    Assert-Example ($null -ne $button -and $button.Current.Name -eq 'Press me') 'Accessible Button missing'
    Assert-Example ($null -ne $field -and $field.Current.Name -eq 'Message') 'Accessible TextField missing'
    Assert-Example ($button.Current.IsKeyboardFocusable -and $field.Current.IsKeyboardFocusable) 'Focus actions missing'
    $invoke = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $value = $field.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    $text = $field.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
    Assert-Example (-not $value.Current.IsReadOnly) 'TextField is read-only'
    Assert-Example ($text.DocumentRange.GetText(-1) -eq 'Hello, AccessKit!') 'Initial TextRun missing'

    # Calls cross the actual adapter boundary, unlike the synthetic smoke views.
    $unicorn = [char]::ConvertFromUtf32(0x1f984)
    $value.SetValue("Odin $unicorn")
    Wait-Example { $value.Current.Value -eq "Odin $unicorn" } 'SetValue callback'
    Assert-Example ($text.DocumentRange.GetText(-1) -eq "Odin $unicorn") 'TextRun did not update'
    $selection = $text.DocumentRange.Clone()
    $selection.MoveEndpointByRange(
        [System.Windows.Automation.Text.TextPatternRangeEndpoint]::End,
        $selection, [System.Windows.Automation.Text.TextPatternRangeEndpoint]::Start)
    [void]$selection.MoveEndpointByUnit(
        [System.Windows.Automation.Text.TextPatternRangeEndpoint]::End,
        [System.Windows.Automation.Text.TextUnit]::Character, 4)
    $selection.Select()
    Wait-Example { $text.GetSelection()[0].GetText(-1) -eq 'Odin' } 'SetTextSelection callback'
    $invoke.Invoke()
    $statusCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        'Button pressed 1 time(s)')
    Wait-Example { $null -ne $root.FindFirst($descendants, $statusCondition) } 'Invoke callback / incremental status update'

    # Empty text must remain a valid TextRun; over-limit and multiline values
    # are rejected atomically, retaining the last accepted value and selection.
    $value.SetValue('')
    Wait-Example { $value.Current.Value -eq '' } 'empty SetValue'
    Assert-Example ($text.DocumentRange.GetText(-1) -eq '') 'Empty TextRun invalid'
    $value.SetValue('a' * 256)
    Wait-Example { $value.Current.Value.Length -eq 256 } 'maximum-length SetValue'
    $value.SetValue('b' * 257)
    $value.SetValue("two`nlines")
    Start-Sleep -Milliseconds 100
    Assert-Example ($value.Current.Value -eq ('a' * 256)) 'Invalid value changed the editor'

    # Keep UIA references alive while the window/adapter are destroyed.
    [void][AccessKitExampleTestNative]::PostMessage($hwnd, 0x0010, [UIntPtr]::Zero, [IntPtr]::Zero)
    Assert-Example ($process.WaitForExit(5000)) 'Window did not shut down with retained UIA providers'
    Assert-Example ($process.ExitCode -eq 0) "Example exited with $($process.ExitCode)"
    Write-Output 'UIA PASS: Button/Value/Text patterns; invoke, value, selection, empty/limit validation, retained-provider shutdown'
} finally {
    if (-not $process.HasExited) {
        [void]$process.CloseMainWindow()
        if (-not $process.WaitForExit(2000)) { $process.Kill(); $process.WaitForExit() }
    }
    $process.Dispose()
}
