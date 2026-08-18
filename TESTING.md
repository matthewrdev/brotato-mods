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

### Persistence

- Save/resume preserves Wish resources, queued items, Paw charges, Calamities,
  locks, and cursed-Lamp discounts.
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
