param([string]$CacheRoot)
$ErrorActionPreference = 'Stop'
function Initialize-AccessKitMsvcEnvironment {
    if ($env:INCLUDE -and $env:LIB -and $env:VSCMD_VER) { return }

    $VsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $VsWhere -PathType Leaf)) {
        if ($env:INCLUDE -and $env:LIB) { return }
        throw 'MSVC environment is not initialized and vswhere.exe was not found. Install the Visual C++ build tools or run from a Visual Studio Developer PowerShell.'
    }

    $Install = & $VsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $Install) {
        throw 'MSVC environment is not initialized and vswhere could not find Visual Studio with the x64 C++ toolchain.'
    }
    $VsDevCmd = Join-Path $Install 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path -LiteralPath $VsDevCmd -PathType Leaf)) {
        throw "MSVC environment setup script was not found: '$VsDevCmd'. Repair the Visual Studio C++ build tools installation."
    }

    $CommandShell = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $CommandShell
    $StartInfo.Arguments = "/d /c call `"$VsDevCmd`" -arch=x64 -host_arch=x64 >nul && set"
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo
    try {
        if (-not $Process.Start()) { throw 'cmd.exe did not start.' }
        $OutputTask = $Process.StandardOutput.ReadToEndAsync()
        $ErrorTask = $Process.StandardError.ReadToEndAsync()
        $Process.WaitForExit()
        $EnvironmentOutput = $OutputTask.GetAwaiter().GetResult()
        $ErrorOutput = $ErrorTask.GetAwaiter().GetResult()
        if ($Process.ExitCode -ne 0) {
            throw "VsDevCmd.bat failed to initialize the x64 C++ environment (exit code $($Process.ExitCode)): $ErrorOutput"
        }
    }
    finally {
        $Process.Dispose()
    }
    $EnvironmentLines = $EnvironmentOutput -split "`r?`n"
    foreach ($Line in $EnvironmentLines) {
        $Separator = $Line.IndexOf('=')
        if ($Separator -le 0) { continue }
        $Name = $Line.Substring(0, $Separator)
        $Value = $Line.Substring($Separator + 1)
        [System.Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    }
    if (-not ($env:INCLUDE -and $env:LIB -and $env:VSCMD_VER)) {
        throw 'VsDevCmd.bat completed without exporting the expected INCLUDE, LIB, and VSCMD_VER variables.'
    }
}

function Get-AccessKitDependency {
    param([string]$CacheRoot)
    $version = '0.23.1'
    $url = "https://github.com/AccessKit/accesskit-c/releases/download/$version/accesskit-c-$version.zip"
    $sha256 = '35b7ca8a6f1e038b5da35e1e9e5a0adaed9bfcf21e1496d29598fbbadcc7043f'
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $cacheRoot = if ($CacheRoot) { [IO.Path]::GetFullPath($CacheRoot) } else { Join-Path $repoRoot '.deps\accesskit' }
    $archive = Join-Path $cacheRoot "accesskit-c-$version.zip"
    $distribution = Join-Path $cacheRoot "accesskit-c-$version"

    # Windows PowerShell on .NET Framework may expose RuntimeInformation
    # without ProcessArchitecture. The process environment remains available
    # there, so use it as the portable fallback and normalize AMD64 to .NET's
    # X64 spelling.
    $architecture = $env:PROCESSOR_ARCHITECTURE
    if ([string]::IsNullOrWhiteSpace($architecture)) {
        try { $architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString() }
        catch { $architecture = '' }
    }
    if ($architecture -eq 'AMD64') { $architecture = 'X64' }
    if ($env:OS -ne 'Windows_NT') { throw "AccessKit static bootstrap does not support this OS in PowerShell: '$env:OS'." }
    if ($architecture -ne 'X64') { throw "AccessKit $version Windows static library is only configured here for x86_64 MSVC; process architecture is '$architecture'." }

    if (-not [IO.Directory]::Exists($cacheRoot)) {
        New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
    }
    if (-not [IO.File]::Exists($archive)) {
        $curl = Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $curl) { throw 'AccessKit bootstrap requires curl.exe to download the pinned release archive.' }
        $download = Join-Path $cacheRoot ('.download-' + [guid]::NewGuid().ToString('N') + '.zip')
        try {
            & $curl.Source --fail --location --silent --show-error --output $download $url
            if ($LASTEXITCODE -ne 0) { throw "AccessKit $version download failed (curl exit $LASTEXITCODE): $url" }
            $downloadHash = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($downloadHash -ne $sha256) { throw "AccessKit $version archive SHA-256 mismatch. Expected $sha256; got $downloadHash." }
            try { [IO.File]::Move($download, $archive) }
            catch {
                if (-not [IO.File]::Exists($archive) -or (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha256) { throw }
            }
        } finally {
            if ([IO.File]::Exists($download)) { Remove-Item -LiteralPath $download -Force }
        }
    }

    $sha256Hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $archiveStream = [IO.File]::OpenRead($archive)
        try {
            $actualHash = [BitConverter]::ToString($sha256Hasher.ComputeHash($archiveStream)).Replace('-', '').ToLowerInvariant()
        } finally {
            $archiveStream.Dispose()
        }
    } finally {
        $sha256Hasher.Dispose()
    }
    if ($actualHash -ne $sha256) {
        throw "AccessKit $version archive SHA-256 mismatch. Expected $sha256; got $actualHash. Cached archive: '$archive'."
    }

    $relativeLibrary = 'lib\windows\x86_64\msvc\static\accesskit.lib'
    $library = Join-Path $distribution $relativeLibrary
    if (-not [IO.File]::Exists($library)) {
        if ([IO.Directory]::Exists($distribution)) {
            if (-not [IO.File]::Exists($library)) {
                throw "AccessKit $version cache exists but the required library is missing: '$library'. Remove only that versioned cache directory and retry."
            }
        } else {
            $stage = Join-Path $cacheRoot ('.extract-' + [guid]::NewGuid().ToString('N'))
            try {
                Expand-Archive -LiteralPath $archive -DestinationPath $stage
                $stagedDistribution = Join-Path $stage "accesskit-c-$version"
                $stagedLibrary = Join-Path $stagedDistribution $relativeLibrary
                if (-not [IO.File]::Exists($stagedLibrary)) {
                    throw "Verified AccessKit archive does not contain the expected Windows x86_64 MSVC static library: '$relativeLibrary'."
                }
                try { [IO.Directory]::Move($stagedDistribution, $distribution) }
                catch {
                    if (-not [IO.File]::Exists($library)) { throw }
                }
            } finally {
                if ([IO.Directory]::Exists($stage)) { Remove-Item -LiteralPath $stage -Recurse -Force }
            }
        }
    }

    $libraryDirectory = Join-Path $distribution 'lib\windows\x86_64\msvc\static'
    $linkerFlags = 'bcrypt.lib ntdll.lib propsys.lib runtimeobject.lib uiautomationcore.lib userenv.lib ws2_32.lib'
    return [pscustomobject]@{
        Root=$distribution; Archive=$archive; Library=$library; LibraryDirectory=$libraryDirectory; LinkerFlags=$linkerFlags
        CompilerArguments=@("-collection:accesskit_c=$libraryDirectory", "-extra-linker-flags:$linkerFlags")
    }
}

if ($MyInvocation.InvocationName -ne '.') { Get-AccessKitDependency -CacheRoot $CacheRoot }
