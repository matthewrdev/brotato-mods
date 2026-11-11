# Testing Wish locally

## Install

1. Fully quit Brotato.
2. Run `./scripts/install_local.sh`.
3. Launch Brotato normally through Steam.
4. Confirm **Wish** appears under **Mods**.

The script builds `dist/Wish-<version>.zip`, taking the version from the
manifest, and installs it as `Wish-local.zip` in a dedicated local Workshop
item folder that ModLoader scans. It also activates that archive in the current
mod profile. Pass another folder as the first argument when needed.

## Automated Brotato 1.2 compatibility test (macOS)

```sh
python3 scripts/test_compatibility.py
```

This builds the current archive, copies the installed PCK into a temporary
folder, redirects ModLoader to test archives, and uses a new
`Brotato-Wish-smoke-*` save directory. It copies profile progress for testing
but starts a fresh run; it never writes to the live profile or installed game.
The running game can stay open. Test files, saves, and logs are retained at the
paths printed by the runner.

Use `--extra-mod /absolute/path/mod.zip` for each additional mod to test.
The runner also accepts `--executable`, `--pack`, and `--profile-source`.

The checks cover content registration after cache rebuilds, native shop pools,
both characters' starting gear, Wish and Crooked Wish reroll delivery, disk
save/resume, Harvesting growth, Corruption, and enemy/Elite spawning with all
five Calamities active. The manual checklist below still covers controller,
co-op, visual layout, and full-run behaviour.

On Brotato 1.2, leave the old ContentLoader and Horde Mode versions disabled;
Wish does not require either of them.

For Brotato 1.2.0.1, use Wish 0.1.3 or later. The shop extension must be
installed in `_ready()`, after RunData is instanced; installing it in `_init()`
causes a type-inference parse error in the game's `base_shop.gdc` at startup.
The automated test loads the real shop scene and exercises Wish delivery to
catch this regression.

After a recovery launch with mods disabled, check the active mod list again.
An empty profile can re-enable every discovered archive on the next normal
launch. Move incompatible archives outside the scanned mod folders if needed;
keep a backup so the change can be reversed. Steam may restore subscribed
Workshop files when they update.

## Smoke test

### Djinn and Wish

- Djinn is unlocked and inherits the profile's available Danger modes.
- Djinn starts with +7 Harvesting, +15% Harvesting modifications, +15% XP gain,
  the selected weapon, and 3 Wishes.
- Wave 1 shows four normal shop slots plus a compact Magic Lamp action showing
  the 3 remaining Wishes. Its tooltip shows the Wish cost and queued items.
- The picker uses tier-coloured cards, respects bans, excludes Magic Lamp, and
  shows locked-tier countdowns.
- Wish costs `25 + 4 × (wave - 1) + 3 × wishes used` materials plus 1 Wish
  resource. Queuing more than one Wish in a shop does not occupy locked slots.
- Queued items appear in normal slots on the next reroll and retain native
  purchase, lock, ban, steal, and reroll behaviour.
- Uncommon, Rare, and Legendary items unlock for Djinn on waves 1, 3, and 6.
- Magic Lamp grants 1 Wish, cannot be locked or banned, and can be bought only
  once per shop visit.
- Wish for Friends appears as a purple Rare item and is eligible for normal
  shops, crates, and Wishes once the Rare tier is available.
- Acquiring Wish for Friends schedules Brotato's native Horde rules for the
  next wave. It remains queued across save/resume and does not duplicate an
  already queued Horde Calamity.
- Wish for Friends is consumed when that wave begins and can appear again in a
  later shop.
- A cursed Wish for Friends shows its bonus in the item text, grants only its
  owner +10% XP Gain for the Horde wave, and restores the previous XP Gain at
  wave end. The pending bonus survives save/resume.

### Wish items

- Wish It Away, Wish You Were Here, Wish for Growth, Wish for Harvest, Wish
  for Corruption, and Wish for Knowledge do not display the Unique label. Multiple
  copies can be bought and their rewards and consequences stack.
- Wish It Away grants 1 Ban token immediately (2 when cursed), enables banning
  if the run had no starting bans, and gives enemies +10% Health for the next
  wave only.
- Wish You Were Here queues one additional Elite and guarantees its crate. A
  cursed copy also guarantees a crate from another enemy during that wave.
  Multiple Hunter effects queue multiple Elites rather than collapsing into
  one.
- Wish for Growth remains in the inventory and increases the native Harvesting
  growth rate by 0.3 percentage points per wave (0.6 when cursed). Multiple
  copies stack, save/resume retains the bonus, and removing a copy reverses it.
  It does not queue crates or extra enemy Damage.
- Wish for Harvest appears as a red Legendary item and permanently grants its
  owner +80 Harvesting (+120 when cursed). It remains in the inventory, stacks
  across copies, and survives save/resume. Enemies have +15% Health during the
  next wave only, and shop item quality follows the normal rules.
- Wish for Corruption appears as a purple Rare item. Buying it curses one
  random uncursed item or weapon in the buyer's inventory; a cursed copy curses
  two distinct eligible entries. Already cursed gear, the Corruption item
  itself, and internal Wish resources are skipped. If fewer targets exist, only
  available targets are cursed. Co-op purchases affect only the buyer.
- After buying Wish for Corruption, the shop refreshes both inventory lists and
  stats, and a dialog names each cursed item or weapon. If none can be cursed,
  the dialog says so. Closing it restores usable shop focus.
- Cursing another Wish item does not replay that item's one-time purchase
  reward. Saving and resuming keeps the cursed inventory without retriggering
  Corruption. Legacy Fortune copies retain their saved item ID but display the
  new name and effect rather than Luck.
- Wish for Knowledge permanently grants +30% XP Gain (+40% when cursed) and
  permanently increases the total number of enemies by 2%. It remains in the
  inventory.
- The three wave-triggered Wish items are consumed when their promised wave
  begins and can roll again in a later shop. Their queued effects survive
  save/resume and stack their enemy Health prices where applicable.

### Shaman and Crooked Wish

- Shaman starts with +5 Curse and +5 Harvesting, gains +1 Curse per level, has
  +15% Elemental and Life Steal modifications, and -50% Melee and Ranged
  modifications.
- The selected weapon, an additional Wand, and Monkey's Paw are all in the
  starting inventory. Shaman does not start with Snake.
- The Paw begins with 3 charges and changes through its 3/2/1/0-finger icons.
- When a character has both the Lamp and the Paw, the shop header shows two
  compact icon actions and remains within the screen at the minimum supported
  resolution. Pending Calamities appear in the Paw tooltip rather than a third
  header control.
- Each Crooked Wish delivers its item on the next reroll and reveals one
  Calamity for the next wave.
- Calamities last one wave: Hunter, Horde, Night, Frenzy, or Famine. Night adds
  +10% enemy speed, and Famine turns 50% of fruit drops into poisoned fruit
  without reducing enemy materials or the number of consumable drops.
- Crooked Wish tiers unlock on waves 1, 3, and 6.

### Controller navigation

- A controller can focus and activate the Magic Lamp and Monkey's Paw actions
  from the shop header, including when both actions are present.
- Opening either picker focuses its first available item. Directional input
  stays within the search, item grid, Confirm, and Cancel controls, and moving
  through the grid keeps the focused card visible.
- Confirm queues the selected item. Controller Back/Cancel closes the picker
  without spending resources, and both paths restore focus to the originating
  shop action (or Reroll when that action becomes unavailable).
- The Crooked Wish reveal dialog focuses its confirmation button and restores
  usable shop focus after closing.
- In local co-op, each player's Lamp/Paw action opens the matching picker and
  returns focus to that player's shop header.

### Persistence

- Save/resume preserves Wish resources, queued items, Paw charges, Calamities,
  locks, cursed-Lamp discounts, Wish item rewards, and their queued wave costs.
- Losing or restarting a Shaman run preserves the correct unused Paw fingers;
  a zero-use Paw restores all 3 charges.
- Rerolling or buying one card does not corrupt the remaining shop slots.

## Logs

```text
~/Library/Application Support/Brotato/logs/modloader.log
~/Library/Application Support/Brotato/logs/godot.log
```

An empty Mods list usually means Brotato was launched with mods disabled. Quit
and choose the normal Steam launch option.
