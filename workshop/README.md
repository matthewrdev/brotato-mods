# Wish Workshop release

Use these values in Brotato's Steam Workshop uploader:

- Title: `Wish`
- Mod ZIP: `dist/Wish-<version>.zip`
- Preview image: `workshop/preview.png`
- Tags: `Characters`, `Items`, `New Mechanics`
- Workshop ID: leave blank for the first upload; reuse the generated ID for
  every update

The internal `Careful-Wish` directory is the ModLoader namespace-qualified ID.
It is not the public mod name and must remain consistent with `namespace` and
`name` in `manifest.json`.

Before publishing:

1. Run `./scripts/package_mod.sh`.
2. Complete the smoke test in `TESTING.md` on the intended Brotato branch.
3. Upload the ZIP and `preview.png` through Steam's `modding` branch.
4. Paste `description.bbcode` into the Workshop description.
5. Keep the item hidden until a clean subscription-only test passes.
6. Mark Abyssal Terrors as required unless the release has been tested without
   the DLC.
