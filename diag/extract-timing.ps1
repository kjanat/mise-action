$ErrorActionPreference = 'Stop'

$mise = Join-Path $env:LOCALAPPDATA 'mise'
$gitTar = 'C:\Program Files\Git\usr\bin\tar.exe'
$bsdTar = Join-Path $env:SystemRoot 'System32\tar.exe'
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
$zst = Join-Path $env:RUNNER_TEMP 'mise.tar.zst'
$plain = Join-Path $env:RUNNER_TEMP 'mise.tar'
$zip = Join-Path $env:RUNNER_TEMP 'mise.zip'

function Write-Summary([string]$line) {
	$line | Out-File -Append -Encoding utf8 $env:GITHUB_STEP_SUMMARY
}

function Measure-Step([string]$name, [scriptblock]$block) {
	$global:LASTEXITCODE = 0
	try {
		$elapsed = Measure-Command { & $block | Out-Host }
		$seconds = [math]::Round($elapsed.TotalSeconds, 1)
		$result = if ($LASTEXITCODE) { "failed with exit code $LASTEXITCODE after ${seconds}s" } else { "$seconds" }
	}
	catch {
		$result = "failed: $($_.Exception.Message)"
	}
	Write-Host "${name}: $result"
	Write-Summary "| $name | $result |"
}

function Expand-With([string]$name, [string]$target, [scriptblock]$block) {
	New-Item -ItemType Directory -Force -Path $target | Out-Null
	Measure-Step $name $block
	Remove-Item -Recurse -Force $target
}

function Expand-ZipParallel([string]$target) {
	$threads = [Environment]::ProcessorCount
	$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
	$dirs = [System.Collections.Generic.HashSet[string]]::new()
	foreach ($entry in $archive.Entries) {
		[void]$dirs.Add([System.IO.Path]::GetDirectoryName((Join-Path $target $entry.FullName)))
	}
	$archive.Dispose()
	foreach ($dir in $dirs) { [void][System.IO.Directory]::CreateDirectory($dir) }
	0..($threads - 1) | ForEach-Object -ThrottleLimit $threads -Parallel {
		$archive = [System.IO.Compression.ZipFile]::OpenRead($using:zip)
		$index = 0
		foreach ($entry in $archive.Entries) {
			if ($entry.Name -and ($index % $using:threads) -eq $_) {
				[System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $using:target $entry.FullName), $true)
			}
			$index++
		}
		$archive.Dispose()
	}
}

$defender = Get-MpComputerStatus
Write-Host "Defender real-time protection: $($defender.RealTimeProtectionEnabled)"
Get-Volume -DriveLetter C, D | Format-Table DriveLetter, FileSystem, Size, SizeRemaining
Get-PhysicalDisk | Format-Table FriendlyName, MediaType, BusType, Size
Write-Host "Logical processors: $([Environment]::ProcessorCount)"
Write-Host "mise dir: $mise"

Write-Summary '### Extraction timings (Windows)'
Write-Summary ''
Write-Summary "Defender real-time protection: $($defender.RealTimeProtectionEnabled). Disks: $((Get-PhysicalDisk | ForEach-Object { "$($_.FriendlyName) ($($_.BusType))" }) -join ', '). Logical processors: $([Environment]::ProcessorCount)."
Write-Summary ''
Write-Summary '| Step | Seconds |'
Write-Summary '|---|---|'

Measure-Step 'pack: Git tar + zstd' { & $gitTar --force-local -cf $zst -C $mise --use-compress-program 'zstd -T0' . }
Measure-Step 'zstd -d to a plain tar' { zstd -d -q -f $zst -o $plain }
Measure-Step 'pack: 7-Zip zip, store only' { & $sevenZip a -tzip -mx=0 -mmt=on -bso0 -bsp0 $zip "$mise\*" }

foreach ($drive in 'C', 'D') {
	Expand-With "Git tar + zstd -> ${drive}:" "${drive}:\x-git-zstd" { & $gitTar --force-local -xf $zst -C "${drive}:\x-git-zstd" --use-compress-program 'zstd -d' }
	Expand-With "Git tar, plain tar -> ${drive}:" "${drive}:\x-git-plain" { & $gitTar --force-local -xf $plain -C "${drive}:\x-git-plain" }
	Expand-With "System32 tar, tar.zst -> ${drive}:" "${drive}:\x-bsd-zstd" { & $bsdTar -xf $zst -C "${drive}:\x-bsd-zstd" }
	Expand-With "System32 tar, plain tar -> ${drive}:" "${drive}:\x-bsd-plain" { & $bsdTar -xf $plain -C "${drive}:\x-bsd-plain" }
	Expand-With "7-Zip zip -> ${drive}:" "${drive}:\x-7z" { & $sevenZip x -mmt=on -bso0 -bsp0 "-o${drive}:\x-7z" $zip }
	Expand-With ".NET ZipFile -> ${drive}:" "${drive}:\x-dotnet" { [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, "${drive}:\x-dotnet", $true) }
	Expand-With ".NET ZipFile, one reader per CPU -> ${drive}:" "${drive}:\x-par" { Expand-ZipParallel "${drive}:\x-par" }
}

Add-MpPreference -ExclusionPath 'C:\x-excluded'
Expand-With 'Git tar + zstd -> C: with Defender exclusion' 'C:\x-excluded' { & $gitTar --force-local -xf $zst -C 'C:\x-excluded' --use-compress-program 'zstd -d' }
Expand-With 'System32 tar, plain tar -> C: with Defender exclusion' 'C:\x-excluded' { & $bsdTar -xf $plain -C 'C:\x-excluded' }

Set-MpPreference -DisableRealtimeMonitoring $true
Expand-With 'Git tar + zstd -> C: with real-time protection off' 'C:\x-rtp-off' { & $gitTar --force-local -xf $zst -C 'C:\x-rtp-off' --use-compress-program 'zstd -d' }
Expand-With 'System32 tar, plain tar -> C: with real-time protection off' 'C:\x-rtp-off' { & $bsdTar -xf $plain -C 'C:\x-rtp-off' }
