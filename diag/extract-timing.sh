#!/usr/bin/env bash
set -euo pipefail

mise=${XDG_DATA_HOME:-$HOME/.local/share}/mise
archive=$RUNNER_TEMP/mise.tar.zst
results=()

measure() {
	local name=$1
	shift
	local start=$EPOCHREALTIME
	"$@"
	local seconds
	seconds=$(awk -v s="$start" -v e="$EPOCHREALTIME" 'BEGIN { printf "%.1f", e - s }')
	echo "$name: ${seconds}s"
	results+=("| $name | $seconds |")
}

df -h "$mise" "$RUNNER_TEMP"
echo "mise dir: $mise"

measure 'pack: tar + zstd' tar -cf "$archive" -C "$mise" --use-compress-program 'zstd -T0' .
mkdir -p /tmp/x-zstd
measure 'tar + zstd -> /tmp' tar -xf "$archive" -C /tmp/x-zstd --use-compress-program 'zstd -d'
rm -r /tmp/x-zstd

{
	printf '### Extraction timings (Linux)\n\n| Step | Seconds |\n|---|---|\n'
	printf '%s\n' "${results[@]}"
} >>"$GITHUB_STEP_SUMMARY"
