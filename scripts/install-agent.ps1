<#
Installs (or updates) LocalRDP Agent on this PC.

What it does:
  1. Copies the agent to "C:\Program Files\LocalRDP Agent".
  2. Exports Sunshine's certificate and private key for the agent. The key is
     encrypted with DPAPI for the current Windows user and stored in
     "%ProgramData%\LocalRDP Agent" (folder readable only by that user and SYSTEM).
     Moonlight already trusts exactly this certificate from pairing with Sunshine.
  3. Allows TCP 48100 in the firewall from the local subnet only (any network
     profile: Windows often marks a home network as Public), for the agent only.
  4. Starts the agent at sign-in (HKCU Run) and starts it now (not elevated).

Run normally; it asks for administrator rights (UAC) for steps 1-3.
  -DryRun   show what would be done, change nothing
#>
param(
    [switch]$DryRun,
    [switch]$Elevated,          # internal: the elevated part
    [string]$UserSid,           # internal: SID of the user who started the install
    [string]$LogFile,           # internal: where the elevated part writes its output
    [string]$Source = (Join-Path $PSScriptRoot '..\moonlight-qt\build\agent-deploy')
)
$ErrorActionPreference = 'Stop'

$InstallDir  = Join-Path $env:ProgramFiles 'LocalRDP Agent'
$DataDir     = Join-Path $env:ProgramData 'LocalRDP Agent'
$Exe         = Join-Path $InstallDir 'LocalRdpAgent.exe'
$SunshineCfg = Join-Path $env:ProgramFiles 'Sunshine\config'
$RuleName    = 'LocalRDP Agent (TCP 48100, local subnet)'
$RunKey      = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$RunValue    = 'LocalRDP Agent'

function Step($text) { Write-Host "  - $text" }
function Do-Or-Show([string]$text, [scriptblock]$action) {
    Step $text
    if (-not $DryRun) { & $action }
}

$me = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal $me).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $Elevated) {
    # ---- Normal (non-elevated) part ----
    $Source = (Resolve-Path $Source).Path
    if (-not (Test-Path (Join-Path $Source 'LocalRdpAgent.exe'))) {
        throw "Agent build not found in $Source. Run scripts\build-agent.bat first."
    }
    if (-not (Test-Path (Join-Path $SunshineCfg 'credentials\cacert.pem'))) {
        throw "Sunshine is not installed in the standard folder ($SunshineCfg)."
    }

    Write-Host "LocalRDP Agent install$(if ($DryRun) {' (dry run: nothing is changed)'})"
    Step "stop a running agent"
    if (-not $DryRun) { Get-Process LocalRdpAgent -ErrorAction SilentlyContinue | Stop-Process -Force }

    # The elevated window closes when done, so it writes what it did to a log file.
    $elevLog = Join-Path $env:TEMP 'localrdp-agent-install.log'
    Remove-Item $elevLog -ErrorAction SilentlyContinue
    if ($DryRun) {
        # Same process tree, no UAC: PowerShell quotes the arguments itself here
        & powershell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Elevated `
            -UserSid $me.User.Value -Source $Source -LogFile $elevLog -DryRun
    } else {
        $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated',
                      '-UserSid', $me.User.Value, '-Source', "`"$Source`"", '-LogFile', "`"$elevLog`"")
        $p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList $elevArgs
        if (Test-Path $elevLog) { Get-Content $elevLog }
        if ($p.ExitCode -ne 0) { throw "The administrator part failed (exit $($p.ExitCode)); see the lines above." }
    }

    Do-Or-Show "start the agent at sign-in (HKCU Run)" {
        Set-ItemProperty -Path $RunKey -Name $RunValue -Value "`"$Exe`""
    }
    Do-Or-Show "start the agent now" {
        Start-Process -FilePath $Exe -WorkingDirectory $InstallDir
        Start-Sleep -Seconds 2
        $listening = Get-NetTCPConnection -LocalPort 48100 -State Listen -ErrorAction SilentlyContinue
        $log = Join-Path $env:LOCALAPPDATA 'LocalRDP Agent\agent.log'
        if ($listening) {
            Write-Host "LocalRDP Agent is running and listening on TCP 48100." -ForegroundColor Green
        } else {
            Write-Warning "The agent is not listening. Last log lines:"
            if (Test-Path $log) { Get-Content $log -Tail 10 }
        }
    }
    exit 0
}

# ---- Elevated part ----
if ($LogFile) { Start-Transcript -Path $LogFile -Force | Out-Null }
trap {
    Write-Host "ERROR: $_"
    if ($LogFile) { Stop-Transcript | Out-Null }
    exit 1
}
if (-not $isAdmin -and -not $DryRun) { throw 'The elevated part must run as administrator.' }
# DPAPI "current user" must be the person who started the install, or the agent
# (running as that person) could not read the key.
if ($me.User.Value -ne $UserSid) {
    throw "Administrator rights were given by a different Windows account. Sign in as an administrator user and run the install again."
}

Do-Or-Show "copy the agent to $InstallDir" {
    New-Item -ItemType Directory -Force $InstallDir | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $InstallDir -Recurse -Force
}

Do-Or-Show "export Sunshine's certificate and DPAPI-protected key to $DataDir" {
    Add-Type -AssemblyName System.Security
    New-Item -ItemType Directory -Force $DataDir | Out-Null
    # Only this user and SYSTEM may read the folder
    & icacls $DataDir /inheritance:r /grant:r "*$($UserSid):(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not restrict access to $DataDir (icacls exit $LASTEXITCODE)." }
    Copy-Item (Join-Path $SunshineCfg 'credentials\cacert.pem') (Join-Path $DataDir 'server.crt') -Force
    $key = [IO.File]::ReadAllBytes((Join-Path $SunshineCfg 'credentials\cakey.pem'))
    try {
        $blob = [Security.Cryptography.ProtectedData]::Protect($key, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes((Join-Path $DataDir 'server.key.dpapi'), $blob)
    } finally {
        [Array]::Clear($key, 0, $key.Length)
    }
}

Do-Or-Show "allow TCP 48100 for the agent from the local subnet" {
    Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 48100 `
        -Profile Any -RemoteAddress LocalSubnet -Program $Exe | Out-Null
}
if ($LogFile) { Stop-Transcript | Out-Null }
exit 0
