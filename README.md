# local-rdp

Build, test and packaging scripts for [Moonlight LocalRDP](https://github.com/emog33k/moonlight-qt) (Windows).

## Layout
```
local-rdp/
  moonlight-qt/   clone of emog33k/moonlight-qt, branch localrdp (with submodules)
  tools/          Qt (scripts/fetch-qt.ps1)
  scripts/        these scripts
  dist/           output
```
The scripts map this folder to drive `L:` (`scripts/env.bat`).

## Requirements
Visual Studio 2022 (C++), Qt 6.11 for MSVC (`scripts/fetch-qt.ps1`), 7-Zip, NSIS 3.

## Scripts
| Script | What it does |
|---|---|
| `test.bat [unit\|ui]` | Builds and runs the tests |
| `build-dev.bat` | Incremental release build of Moonlight (after one full build) |
| `build-agent.bat` | Release build of the agent |
| `make-bundle.bat` | Tests, release build, portable zip |
| `make-installers.bat [nobuild]` | Everything above, then `MoonlightLocalRDP-Setup` and `LocalRDPAgent-Setup` |
| `install-agent.ps1` / `uninstall-agent.ps1` | Installs or removes the agent on the host (`-DryRun` to preview) |
| `rotate-sunshine-keys.ps1` | New Sunshine certificate and key, clears paired clients, reissues the agent certificate |
