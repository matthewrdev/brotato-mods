#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
source "$script_dir/release_info.sh"

default_workshop_root="$HOME/Library/Application Support/Steam/steamapps/workshop/content/1942280"
default_workshop_dir="$default_workshop_root/2931388196"
workshop_dir="${1:-$default_workshop_dir}"
profile_file="$HOME/Library/Application Support/Brotato/mod_user_profiles.json"
installed_archive="$workshop_dir/Wish-local.zip"
legacy_archive="$default_workshop_dir/Wish-0.1.0.zip"

if [[ ! -d "$(dirname "$workshop_dir")" ]]; then
	echo "Brotato Workshop folder not found: $(dirname "$workshop_dir")" >&2
	exit 1
fi

"$script_dir/package_mod.sh"
mkdir -p "$workshop_dir"
cp "$release_archive" "$installed_archive"

# Keep the stale versioned test archive recoverable but out of ModLoader's
# scan. The current build uses a stable local filename in this subscribed
# numeric Workshop folder because ModLoader ignores ZIPs under local-wish.
if [[ "$workshop_dir" == "$default_workshop_dir" && -e "$legacy_archive" ]]; then
	legacy_disabled="$legacy_archive.disabled"
	if [[ -e "$legacy_disabled" ]]; then
		legacy_disabled="$legacy_disabled.$(date +%Y%m%d%H%M%S)"
	fi
	mv "$legacy_archive" "$legacy_disabled"
	echo "Disabled legacy duplicate $legacy_archive"
fi

if [[ -f "$profile_file" ]]; then
	profile_tmp="$(mktemp "$profile_file.tmp.XXXXXX")"
	jq --arg archive "$installed_archive" '
		(.current_profile // "default") as $profile
		| .profiles[$profile].mod_list["Careful-Wish"] =
			((.profiles[$profile].mod_list["Careful-Wish"] // {}) + {
				"is_active": true,
				"zip_path": $archive
			})
	' "$profile_file" > "$profile_tmp"
	chmod "$(stat -f '%Lp' "$profile_file")" "$profile_tmp"
	mv "$profile_tmp" "$profile_file"
	echo "Activated $installed_archive in the current Brotato mod profile"
fi

echo "Installed $installed_archive from $(basename "$release_archive")"
echo "Fully quit and restart Brotato before testing."
