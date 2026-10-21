<#
Removes LocalRDP Agent from this PC: stops it, removes autostart, the firewall rule,
the program folder and the exported Sunshine certificate/key.
  -DryRun   show what would be done, change nothing
#>
param([switch]$DryRun, [switch]$Elevated)
$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:ProgramFiles 'LocalRDP Agent'
$DataDir    = Join-Path $env:ProgramData 'LocalRDP Agent'
$RuleName   = 'LocalRDP Agent (TCP 48100, local subnet)'
$RunKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

function Do-Or-Show([string]$text, [scriptblock]$action) {
    Write-Host "  - $text"
    if (-not $DryRun) { & $action }
}

if (-not $Elevated) {
    Write-Host "LocalRDP Agent uninstall$(if ($DryRun) {' (dry run: nothing is changed)'})"
    Do-Or-Show "stop the agent" { Get-Process LocalRdpAgent -ErrorAction SilentlyContinue | Stop-Process -Force }
    Do-Or-Show "remove autostart" { Remove-ItemProperty -Path $RunKey -Name 'LocalRDP Agent' -ErrorAction SilentlyContinue }
    $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated')
    if ($DryRun) { & powershell @($elevArgs + '-DryRun') }
    else {
        $p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList $elevArgs
        if ($p.ExitCode -ne 0) { throw "The administrator part failed (exit $($p.ExitCode))." }
        Write-Host "LocalRDP Agent removed." -ForegroundColor Green
    }
    exit 0
}

Do-Or-Show "remove the firewall rule" {
    Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}
Do-Or-Show "delete $InstallDir" { Remove-Item -Recurse -Force $InstallDir -ErrorAction SilentlyContinue }
Do-Or-Show "delete $DataDir (exported certificate and key)" { Remove-Item -Recurse -Force $DataDir -ErrorAction SilentlyContinue }
exit 0
