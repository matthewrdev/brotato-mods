# Wish Workshop release

Use these values in Brotato's Steam Workshop uploader:

- Title: `Wish`
- Mod ZIP: `dist/Wish-0.1.3.zip`
- Preview image: `workshop/preview.png`
- Tags: `Characters`, `Items`, `New Mechanics`
- Workshop ID: `3790161580` for updates. Do not use the local test folder's ID.

The internal `Careful-Wish` directory is the ModLoader namespace-qualified ID.
It is not the public mod name and must remain consistent with `namespace` and
`name` in `manifest.json`.

For this update:

1. Fully quit Brotato, then test `dist/Wish-0.1.3.zip` using `TESTING.md` on
   the intended Brotato branch. In particular, buy Wish for Growth and Wish
   for Corruption and check their effects after saving and resuming.
2. In Steam, open Brotato's Properties > Betas and select the `modding` branch.
   Launch the Godot Workshop Utility **through Steam**.
3. Select `dist/Wish-0.1.3.zip` as the mod file and `workshop/preview.png` as
   the preview image. Enter Workshop item ID `3790161580` to update Wish;
   leaving that field blank creates a separate item.
4. Paste `workshop/description.bbcode` into the Workshop description and use
   `workshop/release-notes-0.1.3.md` for the update notes.
5. For a first upload, leave the new item hidden while testing it. For an
   existing public item, complete the local smoke test before uploading because
   the update will be public immediately. For a subscription-only check, first
   disable the local `Wish-local.zip` test copy so ModLoader loads one Wish copy.
   Mark Abyssal Terrors as required unless the release has been tested without
   it.
