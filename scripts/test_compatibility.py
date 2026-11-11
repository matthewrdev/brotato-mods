#!/usr/bin/env python3
"""Run the 1.2 integration smoke test on macOS without touching the live profile.

Only the temporary PCK's ModLoader options are patched; the installed game and
Workshop archives are read-only. Test saves and logs are retained for inspection.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import tempfile


def patch_test_pack(source, target, mods_dir):
    shutil.copy2(source, target)
    with target.open('r+b') as pack:
        magic, version = struct.unpack('<II', pack.read(8))
        if magic != 0x43504447 or version != 1:
            raise ValueError('Expected the Brotato 1.2 Godot PCK v1 format')
        pack.seek(84)
        count, = struct.unpack('<I', pack.read(4))
        entries = []
        for _ in range(count):
            length, = struct.unpack('<I', pack.read(4))
            name = pack.read(length).rstrip(b'\0').decode()
            entry_position = pack.tell()
            offset, size = struct.unpack('<QQ', pack.read(16))
            pack.read(16)  # MD5
            if name.startswith('res://addons/mod_loader/options/profiles/') and name.endswith('.tres'):
                entries.append((entry_position, offset, size))
        if not entries:
            raise ValueError('No ModLoader options found; refusing to run with live Workshop mods')
        for entry_position, offset, size in entries:
            pack.seek(offset)
            options = pack.read(size).decode()
            options = options.replace('steam_workshop_enabled = true', 'steam_workshop_enabled = false')
            options = options.replace('override_path_to_mods = ""', f'override_path_to_mods = "{mods_dir}"')
            data = options.encode()
            pack.seek(0, 2)
            new_offset = pack.tell()
            pack.write(data)
            pack.seek(entry_position)
            pack.write(struct.pack('<QQ', new_offset, len(data)) + hashlib.md5(data).digest())


def main():
    support = Path.home() / 'Library/Application Support'
    default_game = support / 'Steam/steamapps/common/Brotato/Brotato.app/Contents'
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--executable', type=Path, default=default_game / 'MacOS/Brotato')
    parser.add_argument('--pack', type=Path, default=default_game / 'Resources/Brotato.pck')
    parser.add_argument('--profile-source', type=Path, default=support / 'Brotato')
    parser.add_argument('--extra-mod', type=Path, action='append', default=[])
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    manifest = json.loads((repo / 'root/mods-unpacked/Careful-Wish/manifest.json').read_text())
    subprocess.run([str(repo / 'scripts/package_mod.sh')], check=True)
    archive = repo / 'dist' / f"Wish-{manifest['version_number']}.zip"
    work = Path(tempfile.mkdtemp(prefix='wish-compat-')).resolve()
    mods = work / 'mods'
    mods.mkdir()
    for mod in [archive] + args.extra_mod:
        destination = mods / mod.name
        if destination.exists():
            raise ValueError(f'Duplicate mod archive name: {mod.name}')
        shutil.copy2(mod, destination)
    patch_test_pack(args.pack, work / 'Brotato.pck', mods)
    user_dir_name = 'Brotato-Wish-smoke-' + work.name.removeprefix('wish-compat-')
    user_dir = support / user_dir_name
    user_dir.mkdir()  # Never reuse an existing profile.
    for source in args.profile_source.iterdir():
        if not source.is_dir() or not (source.name.isdigit() or source.name == 'user'):
            continue
        destination = user_dir / source.name
        destination.mkdir()
        for filename in ['settings.json', 'save_v3_0.json']:
            if (source / filename).is_file():
                shutil.copy2(source / filename, destination / filename)
        (destination / 'run_v3_0.json').write_text(json.dumps({'current_run_state': {'has_run_state': False}}))
    (work / 'override.cfg').write_text(
        '[application]\nconfig/use_custom_user_dir=true\n'
        f'config/custom_user_dir_name="{user_dir_name}"\n'
    )
    command = [str(args.executable.resolve()), '-ApplePersistenceIgnoreState', 'YES',
               '--main-pack', str(work / 'Brotato.pck'), '--script',
               str(repo / 'tests/compatibility_smoke.gd'), '--no-window', '--audio-driver', 'Dummy']
    print(f'Test files: {work}\nTest saves: {user_dir}', flush=True)
    with (work / 'stdout.log').open('wb') as stdout, (work / 'stderr.log').open('wb') as stderr:
        result = subprocess.run(command, cwd=work, env=dict(os.environ, SteamAppId='1942280'),
                                stdout=stdout, stderr=stderr, timeout=60)
    output = (work / 'stdout.log').read_text(errors='replace')
    errors = (work / 'stderr.log').read_text(errors='replace')
    for line in output.splitlines():
        if line.startswith(('PASS:', 'FAIL:', 'WISH_SMOKE_')):
            print(line)
    # Godot's release build reports resource leaks on scripted shutdown even
    # without Wish. Script errors are failures regardless of the exit code.
    passed = result.returncode == 0 and 'WISH_SMOKE_FAILURES: 0' in output
    passed = passed and 'SCRIPT ERROR' not in output + errors
    # A requested extra mod can be silently skipped when a dependency is absent.
    passed = passed and 'Missing dependency - mod:' not in output + errors
    if not passed:
        print(output[-4000:])
        print(errors[-4000:])
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
