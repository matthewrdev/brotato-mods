#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
source "$script_dir/release_info.sh"

mkdir -p "$repo_dir/dist"
rm -f "$release_archive"
(
	cd "$repo_dir/root"
	zip -q -r "$release_archive" "mods-unpacked/$release_mod_id" \
		-x '*/.DS_Store' '*/__MACOSX/*' '*/.godot/*'
)

unzip -tq "$release_archive"
archive_entries="$(unzip -Z1 "$release_archive")"

if ! grep -Fxq "mods-unpacked/$release_mod_id/manifest.json" <<< "$archive_entries"; then
	echo "Release archive is missing manifest.json" >&2
	exit 1
fi

if ! grep -Fxq "mods-unpacked/$release_mod_id/mod_main.gd" <<< "$archive_entries"; then
	echo "Release archive is missing mod_main.gd" >&2
	exit 1
fi

echo "Built $release_archive"
