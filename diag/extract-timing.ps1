$ErrorActionPreference = 'Stop'

$mise = Join-Path $env:LOCALAPPDATA 'mise'
$gitTar = 'C:\Program Files\Git\usr\bin\tar.exe'
$bsdTar = Join-Path $env:SystemRoot 'System32\tar.exe'
$archive = Join-Path $env:RUNNER_TEMP 'mise.tar.zst'
$plain = Join-Path $env:RUNNER_TEMP 'mise.tar'
$results = [System.Collections.Generic.List[object]]::new()

function Measure-Step([string]$name, [scriptblock]$block) {
	$elapsed = Measure-Command { & $block }
	if ($LASTEXITCODE) { throw "$name exited with $LASTEXITCODE" }
	$seconds = [math]::Round($elapsed.TotalSeconds, 1)
	Write-Host "${name}: ${seconds}s"
	$results.Add([pscustomobject]@{ Step = $name; Seconds = $seconds })
}

function Expand-With([string]$name, [string]$target, [scriptblock]$block) {
	New-Item -ItemType Directory -Force -Path $target | Out-Null
	Measure-Step $name $block
	Remove-Item -Recurse -Force $target
}

$defender = Get-MpComputerStatus
Write-Host "Defender real-time protection: $($defender.RealTimeProtectionEnabled)"
Write-Host "Defender antivirus enabled: $($defender.AntivirusEnabled)"
Get-Volume -DriveLetter C, D | Format-Table DriveLetter, FileSystem, Size, SizeRemaining
Get-PhysicalDisk | Format-Table FriendlyName, MediaType, BusType, Size
Write-Host "mise dir: $mise"

Measure-Step 'pack: git tar + zstd' { & $gitTar -cf $archive -C $mise --use-compress-program 'zstd -T0' . }
Measure-Step 'zstd -d to a plain tar on D:' { zstd -d -q -f $archive -o $plain }

Expand-With 'git tar + zstd -> C:' 'C:\x-git-zstd' { & $gitTar -xf $archive -C 'C:\x-git-zstd' --use-compress-program 'zstd -d' }
Expand-With 'git tar + zstd -> D:' 'D:\x-git-zstd' { & $gitTar -xf $archive -C 'D:\x-git-zstd' --use-compress-program 'zstd -d' }
Expand-With 'git tar, plain tar -> C:' 'C:\x-git-plain' { & $gitTar -xf $plain -C 'C:\x-git-plain' }
Expand-With 'System32 bsdtar, plain tar -> C:' 'C:\x-bsd-plain' { & $bsdTar -xf $plain -C 'C:\x-bsd-plain' }

Add-MpPreference -ExclusionPath 'C:\x-excluded'
Expand-With 'git tar + zstd -> C: with Defender exclusion' 'C:\x-excluded' { & $gitTar -xf $archive -C 'C:\x-excluded' --use-compress-program 'zstd -d' }
Expand-With 'System32 bsdtar -> C: with Defender exclusion' 'C:\x-excluded' { & $bsdTar -xf $plain -C 'C:\x-excluded' }

Set-MpPreference -DisableRealtimeMonitoring $true
Write-Host "Defender real-time protection: $((Get-MpComputerStatus).RealTimeProtectionEnabled)"
Expand-With 'git tar + zstd -> C: with real-time protection off' 'C:\x-rtp-off' { & $gitTar -xf $archive -C 'C:\x-rtp-off' --use-compress-program 'zstd -d' }
Expand-With 'System32 bsdtar -> C: with real-time protection off' 'C:\x-rtp-off' { & $bsdTar -xf $plain -C 'C:\x-rtp-off' }

$table = $results | ForEach-Object { "| $($_.Step) | $($_.Seconds) |" }
@('### Extraction timings (Windows)', '', '| Step | Seconds |', '|---|---|') + $table |
	Out-File -Append -Encoding utf8 $env:GITHUB_STEP_SUMMARY
