param([string]$Odin = 'odin', [switch]$Smoke)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\bootstrap.ps1"
Initialize-AccessKitMsvcEnvironment
$Root = (Resolve-Path "$PSScriptRoot\..").Path
$Dependency = Get-AccessKitDependency
New-Item -ItemType Directory -Force (Join-Path $Root 'out') | Out-Null
& $Odin build "$Root\examples\windows" "-collection:accesskit=$Root" @($Dependency.CompilerArguments) "-out:$Root\out\accesskit_windows.exe"
if ($LASTEXITCODE) { throw 'Native example build failed' }
if ($Smoke) { & "$Root\out\accesskit_windows.exe" --smoke } else { & "$Root\out\accesskit_windows.exe" }
exit $LASTEXITCODE
