#!/usr/bin/env bash

# Shared release metadata. This file is sourced by the build and install
# scripts so the manifest remains the single source of truth.

release_mod_id="Careful-Wish"
release_mod_dir="$repo_dir/root/mods-unpacked/$release_mod_id"
release_manifest="$release_mod_dir/manifest.json"

if [[ ! -f "$release_manifest" ]]; then
	echo "Manifest not found: $release_manifest" >&2
	exit 1
fi

release_name="$(awk -F '"' '$2 == "name" { print $4; exit }' "$release_manifest")"
release_namespace="$(awk -F '"' '$2 == "namespace" { print $4; exit }' "$release_manifest")"
release_version="$(awk -F '"' '$2 == "version_number" { print $4; exit }' "$release_manifest")"

if [[ -z "$release_name" || -z "$release_namespace" || -z "$release_version" ]]; then
	echo "Manifest must define name, namespace, and version_number" >&2
	exit 1
fi

if [[ "$release_name" != "Wish" ]]; then
	echo "Public mod name must be Wish, found: $release_name" >&2
	exit 1
fi

if [[ "$release_namespace-$release_name" != "$release_mod_id" ]]; then
	echo "Manifest identity must match folder $release_mod_id" >&2
	exit 1
fi

if [[ ! "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
	echo "Invalid version_number: $release_version" >&2
	exit 1
fi

release_archive="$repo_dir/dist/$release_name-$release_version.zip"
