#!/usr/bin/env bash
set -uo pipefail

mise=${XDG_DATA_HOME:-$HOME/.local/share}/mise
zst=$RUNNER_TEMP/mise.tar.zst
plain=$RUNNER_TEMP/mise.tar
zip=$RUNNER_TEMP/mise.zip
threads=$(nproc)

summary() {
	printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
}

measure() {
	local name=$1
	shift
	local start=$EPOCHREALTIME status=0
	"$@" || status=$?
	local seconds result
	seconds=$(awk -v s="$start" -v e="$EPOCHREALTIME" 'BEGIN { printf "%.1f", e - s }')
	if ((status)); then
		result="failed with exit code $status after ${seconds}s"
	else
		result=$seconds
	fi
	echo "$name: $result"
	summary "| $name | $result |"
}

expand() {
	local name=$1 target=$2
	shift 2
	sudo mkdir -p "$target"
	sudo chown "$USER" "$target"
	measure "$name" "$@"
}

unzip_parallel() {
	python3 - "$zip" "$1" "$threads" <<'EOF'
import multiprocessing, sys, zipfile
from concurrent.futures import ProcessPoolExecutor

archive, target, threads = sys.argv[1], sys.argv[2], int(sys.argv[3])

def extract(part):
    with zipfile.ZipFile(archive) as z:
        for index, info in enumerate(z.infolist()):
            if index % threads == part:
                z.extract(info, target)

with ProcessPoolExecutor(threads, mp_context=multiprocessing.get_context("fork")) as pool:
    list(pool.map(extract, range(threads)))
EOF
}

sudo apt-get install --yes --no-install-recommends libarchive-tools

df -h / "$RUNNER_TEMP"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
echo "Logical processors: $threads"
echo "mise dir: $mise"
command -v bsdtar 7z unzip

summary '### Extraction timings (Linux)'
summary ''
summary "Root disk: $(findmnt -no SOURCE /). Logical processors: $threads."
summary ''
summary '| Step | Seconds |'
summary '|---|---|'

measure 'pack: GNU tar + zstd' tar -cf "$zst" -C "$mise" --use-compress-program 'zstd -T0' .
measure 'zstd -d to a plain tar' zstd -d -q -f "$zst" -o "$plain"
measure 'pack: 7-Zip zip, store only' 7z a -tzip -mx=0 -mmt=on -snl -bso0 -bsp0 "$zip" "$mise/*"

root=$HOME
expand "GNU tar + zstd -> $root" "$root/x-gnu-zstd" tar -xf "$zst" -C "$root/x-gnu-zstd" --use-compress-program 'zstd -d'
expand "GNU tar, plain tar -> $root" "$root/x-gnu-plain" tar -xf "$plain" -C "$root/x-gnu-plain"
expand "bsdtar, tar.zst -> $root" "$root/x-bsd-zstd" bsdtar -xf "$zst" -C "$root/x-bsd-zstd"
expand "bsdtar, plain tar -> $root" "$root/x-bsd-plain" bsdtar -xf "$plain" -C "$root/x-bsd-plain"
expand "7-Zip zip -> $root" "$root/x-7z" 7z x -mmt=on -bso0 -bsp0 "-o$root/x-7z" "$zip"
expand "unzip -> $root" "$root/x-unzip" unzip -q "$zip" -d "$root/x-unzip"
expand "Python zipfile, one process per CPU -> $root" "$root/x-par" unzip_parallel "$root/x-par"
