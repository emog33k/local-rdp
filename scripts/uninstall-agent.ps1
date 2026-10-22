<#
Removes LocalRDP Agent from this PC: stops it, removes autostart, the firewall rule,
the program folder and the agent's certificate/key.
  -DryRun   show what would be done, change nothing
#>
param([switch]$DryRun, [switch]$Elevated)
$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:ProgramFiles 'LocalRDP Agent'
$DataDir    = Join-Path $env:ProgramData 'LocalRDP Agent'
$RuleName   = 'LocalRDP Agent (TCP 48100, local subnet)'
$RunKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$PowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Do-Or-Show([string]$text, [scriptblock]$action) {
    Write-Host "  - $text"
    if (-not $DryRun) { & $action }
}

if (-not $Elevated) {
    Write-Host "LocalRDP Agent uninstall$(if ($DryRun) {' (dry run: nothing is changed)'})"
    Do-Or-Show "stop the agent" {
        # This Windows session's agent only
        $session = (Get-Process -Id $PID).SessionId
        foreach ($a in @(Get-Process LocalRdpAgent -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $session })) {
            Stop-Process -Id $a.Id -Force -ErrorAction SilentlyContinue
            Wait-Process -Id $a.Id -Timeout 10 -ErrorAction SilentlyContinue
        }
    }
    Do-Or-Show "remove autostart" { Remove-ItemProperty -Path $RunKey -Name 'LocalRDP Agent' -ErrorAction SilentlyContinue }
    $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated')
    if ($DryRun) {
        & $PowerShell @($elevArgs + '-DryRun')
        if ($LASTEXITCODE -ne 0) { throw "The administrator part failed (exit $LASTEXITCODE)." }
    }
    else {
        $p = Start-Process $PowerShell -Verb RunAs -Wait -PassThru -ArgumentList $elevArgs
        if ($p.ExitCode -ne 0) { throw "The administrator part failed (exit $($p.ExitCode))." }
        Write-Host "LocalRDP Agent removed." -ForegroundColor Green
    }
    exit 0
}

Do-Or-Show "remove the firewall rule" {
    Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}
Do-Or-Show "delete $InstallDir" { Remove-Item -Recurse -Force $InstallDir -ErrorAction SilentlyContinue }
Do-Or-Show "delete $DataDir (the agent's certificate and key)" { Remove-Item -Recurse -Force $DataDir -ErrorAction SilentlyContinue }
exit 0
