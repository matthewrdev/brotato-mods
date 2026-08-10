# Testing Wish locally

## Install

1. Fully quit Brotato.
2. Run `./scripts/install_local.sh`.
3. Launch Brotato normally through Steam.
4. Confirm **Wish** appears under **Mods**.

The script builds `dist/Wish-<version>.zip`, taking the version from the
manifest, and installs it as `Wish-local.zip` in a dedicated local Workshop
folder. Pass another folder as the first argument when needed.

## Smoke test

### Djinn and Wish

- Djinn is unlocked and inherits the profile's available Danger modes.
- Djinn starts with +5 Harvesting, +15% Harvesting modifications, +20% XP gain,
  the selected weapon, and 3 Wishes.
- Wave 1 shows four normal shop slots plus an external **Wish — 30** action.
- The picker uses tier-coloured cards, respects bans, excludes Magic Lamp, and
  shows locked-tier countdowns.
- Wish costs `30 + 4 × (wave - 1) + 3 × wishes used` materials plus 1 Wish resource. Queuing more
  than one Wish in a shop does not occupy locked slots.
- Queued items appear in normal slots on the next reroll and retain native
  purchase, lock, ban, steal, and reroll behaviour.
- Uncommon, Rare, and Legendary items unlock for Djinn on waves 1, 3, and 6.
- Magic Lamp grants 1 Wish, cannot be locked or banned, and can be bought only
  once per shop visit.

### Shaman and Crooked Wish

- Shaman starts with +5 Curse, gains +1 Curse per level, has +15% Elemental and
  Life Steal modifications, and -50% Melee and Ranged modifications.
- Snake and Monkey's Paw are both in the starting inventory.
- The Paw begins with 3 charges and changes through its 3/2/1/0-finger icons.
- Each Crooked Wish delivers its item on the next reroll and reveals one
  Calamity for the next wave.
- Calamities last one wave: Hunter, Horde, Night, Frenzy, or Famine. Night adds
  +10% enemy speed.
- Crooked Wish tiers unlock on waves 1, 3, and 6.

### Persistence

- Save/resume preserves Wish resources, queued items, Paw charges, Calamities,
  locks, and cursed-Lamp discounts.
- Rerolling or buying one card does not corrupt the remaining shop slots.

## Logs

```text
~/Library/Application Support/Brotato/logs/modloader.log
~/Library/Application Support/Brotato/logs/godot.log
```

An empty Mods list usually means Brotato was launched with mods disabled. Quit
and choose the normal Steam launch option.
