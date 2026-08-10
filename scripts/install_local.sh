#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
source "$script_dir/release_info.sh"

default_workshop_root="$HOME/Library/Application Support/Steam/steamapps/workshop/content/1942280"
default_workshop_dir="$default_workshop_root/local-wish"
workshop_dir="${1:-$default_workshop_dir}"

if [[ ! -d "$(dirname "$workshop_dir")" ]]; then
	echo "Brotato Workshop folder not found: $(dirname "$workshop_dir")" >&2
	exit 1
fi

"$script_dir/package_mod.sh"
mkdir -p "$workshop_dir"
cp "$release_archive" "$workshop_dir/Wish-local.zip"
echo "Installed $workshop_dir/Wish-local.zip from $(basename "$release_archive")"
echo "Fully quit and restart Brotato before testing."
