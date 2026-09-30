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

- Wish It Away, Wish You Were Here, Wish for Treasure, Wish for Harvest, Wish
  for Fortune, and Wish for Knowledge do not display the Unique label. Multiple
  copies can be bought and their rewards and consequences stack.
- Wish It Away grants 1 Ban token immediately (2 when cursed), enables banning
  if the run had no starting bans, and gives enemies +10% Health for the next
  wave only.
- Wish You Were Here queues one additional Elite and guarantees its crate. A
  cursed copy also guarantees a crate from another enemy during that wave.
  Multiple Hunter effects queue multiple Elites rather than collapsing into
  one.
- Wish for Treasure guarantees 1 normal crate drop during the next wave (2
  when cursed) and gives enemies +10% Damage for that wave only.
- Wish for Harvest appears as a red Legendary item and permanently grants its
  owner +80 Harvesting (+120 when cursed). It remains in the inventory, stacks
  across copies, and survives save/resume. Enemies have +15% Health during the
  next wave only, and shop item quality follows the normal rules.
- Wish for Fortune permanently grants its owner +25 Luck (+40 when cursed),
  remains in the inventory, and gives enemies +10% Damage for the next wave
  only.
- Wish for Knowledge permanently grants +30% XP Gain (+40% when cursed) and
  permanently increases the total number of enemies by 2%. It remains in the
  inventory.
- The four wave-triggered Wish items are consumed when their promised wave
  begins and can roll again in a later shop. Their queued effects survive
  save/resume and stack their enemy Health or Damage prices where applicable.

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
