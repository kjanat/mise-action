$ErrorActionPreference = 'Stop'

function Write-Summary([string]$line) {
	$line | Out-File -Append -Encoding utf8 $env:GITHUB_STEP_SUMMARY
}

function New-VhdxVolume([string]$name, [char]$letter, [string]$fileSystem, [switch]$DevDrive) {
	$path = "D:\$name.vhdx"
	$script = Join-Path $env:RUNNER_TEMP "$name.diskpart"
	# Dev Drive volumes must be at least 50 GB.
	"create vdisk file=`"$path`" maximum=51200 type=expandable" | Out-File -Encoding ascii $script
	try {
		$elapsed = Measure-Command {
			diskpart /s $script | Out-Host
			if ($LASTEXITCODE) { throw "diskpart exited with $LASTEXITCODE" }
			$disk = Mount-DiskImage -ImagePath $path -PassThru | Get-Disk
			Initialize-Disk -Number $disk.Number -PartitionStyle GPT
			New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $letter | Out-Null
			$format = @{ DriveLetter = $letter; FileSystem = $fileSystem; Confirm = $false; Force = $true }
			if ($DevDrive) { $format.DevDrive = $true }
			Format-Volume @format | Out-Host
			if ($DevDrive) {
				fsutil devdrv trust "${letter}:" | Out-Host
				fsutil devdrv query "${letter}:" | Out-Host
			}
		}
		$result = [math]::Round($elapsed.TotalSeconds, 1)
	}
	catch {
		$result = "failed: $($_.Exception.Message)"
	}
	Write-Host "create ${name} (${letter}:): $result"
	Write-Summary "| create $name as ${letter}: | $result |"
}

Write-Summary '### VHDX volumes on D:'
Write-Summary ''
Write-Summary '| Step | Seconds |'
Write-Summary '|---|---|'

New-VhdxVolume 'refs-devdrive' 'R' 'ReFS' -DevDrive
New-VhdxVolume 'refs' 'F' 'ReFS'
New-VhdxVolume 'ntfs' 'N' 'NTFS'

Get-Volume | Where-Object DriveLetter | Format-Table DriveLetter, FileSystem, FileSystemLabel, Size, SizeRemaining
