param([string]$Odin = 'odin', [switch]$SkipNativeExample, [string]$CacheRoot)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\bootstrap.ps1" -CacheRoot $CacheRoot
Initialize-AccessKitMsvcEnvironment
$Root = (Resolve-Path "$PSScriptRoot\..").Path
$Dependency = Get-AccessKitDependency -CacheRoot $CacheRoot
$Odin = (Get-Command $Odin -CommandType Application -ErrorAction Stop).Source
$Out = Join-Path $Root 'out'
New-Item -ItemType Directory -Force $Out | Out-Null
$PreviousLib = $env:LIB
$env:LIB = "$Out;$env:LIB"
Push-Location $Root
try {
    & cl /nologo /std:c11 /W4 /WX "/I$($Dependency.Root)\include" tests\abi_contract\accesskit_abi_contract.c "/Fo$Out\contract.obj" "/Fe$Out\contract.exe"
    if ($LASTEXITCODE) { throw 'C header contract compile failed' }
    & "$Out\contract.exe"
    if ($LASTEXITCODE) { throw 'C header contract failed' }
    & cl /nologo /std:c11 /W4 /WX "/I$($Dependency.Root)\include" /c tests\abi_contract\accesskit_abi_round_trip.c "/Fo$Out\round_trip.obj"
    if ($LASTEXITCODE) { throw 'C aggregate probe compile failed' }
    & lib /nologo "/OUT:$Out\odin_accesskit_abi_probe.lib" "$Out\round_trip.obj"
    if ($LASTEXITCODE) { throw 'C aggregate probe archive failed' }
    & python tools/generate_constants.py --check
    if ($LASTEXITCODE) { throw 'Generated enum coverage check failed' }
    $Arguments = @($Dependency.CompilerArguments)
    & $Odin check accesskit -no-entry-point "-collection:accesskit_c=$($Dependency.LibraryDirectory)"
    if ($LASTEXITCODE) { throw 'Binding check failed' }
    & $Odin test accesskit @Arguments "-out:$Out\accesskit_tests.exe"
    if ($LASTEXITCODE) { throw 'Binding tests failed' }
    # Build from outside this repository to detect hidden relative imports.
    $External = Join-Path ([IO.Path]::GetTempPath()) ('odin-accesskit-consumer-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $External | Out-Null
    try {
        Copy-Item examples\minimal_tree\main.odin $External
        Push-Location $External
        try {
            & $Odin build . "-collection:accesskit=$Root" @($Dependency.CompilerArguments) "-out:$External\consumer.exe"
            if ($LASTEXITCODE) { throw 'External consumer build failed' }
            & "$External\consumer.exe"
            if ($LASTEXITCODE) { throw 'External consumer failed' }
        } finally { Pop-Location; $env:LIB = $PreviousLib }
    } finally {
        $Resolved = [IO.Path]::GetFullPath($External)
        if (-not $Resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid temporary consumer cleanup path' }
        Remove-Item -LiteralPath $Resolved -Recurse -Force
    }
    if (-not $SkipNativeExample) {
        & $Odin build examples\windows "-collection:accesskit=$Root" @($Dependency.CompilerArguments) "-out:$Out\accesskit_windows.exe"
        if ($LASTEXITCODE) { throw 'Native example build failed' }
        & "$Out\accesskit_windows.exe" --smoke
        if ($LASTEXITCODE) { throw 'Native example smoke failed' }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File examples/windows/verify-uia.ps1 -Executable "$Out\accesskit_windows.exe"
        if ($LASTEXITCODE) { throw 'Native UIA contract failed' }
    }
} finally { Pop-Location; $env:LIB = $PreviousLib }
