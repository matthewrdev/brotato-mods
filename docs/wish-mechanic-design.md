# Wish implementation notes

## Rules

- Wish is an external shop action; all four shop cards remain native.
- A Wish costs 1 Wish resource plus
  `25 + 4 × (wave - 1) + 3 × wishes used` materials.
- Multiple items may be queued for the next successful reroll, limited by
  unlocked shop slots.
- Queued items become ordinary cards with native prices and behaviour.
- Eligibility respects unlocks, bans, character exclusions, ownership caps,
  endless restrictions, and removed shop groups.
- Magic Lamp is never wishable. It is repeatable across a run, limited to one
  purchase per shop visit, and cannot be locked or banned.
- The seven unlocked-by-default Wish items can be rolled, looted, or selected
  through Wish once their tiers are available. Four are one-wave triggers and
  are consumed when the promised wave begins; Wish for Harvest, Wish for
  Fortune, and Wish for Knowledge are permanent.
- The six additional Wish items are repeatable (`max_nb = -1`), so copies may
  be held together and their rewards and consequences stack.
- Cursed Wish items improve the reward while retaining the same negative
  effect. Temporary player and enemy stats are restored from captured pre-wave
  values, so they compose with other mods and co-op players.

Djinn and Crooked Wish unlock Uncommon on wave 1, Rare on wave 3, and Legendary
on wave 6. Other Lamp-enabled characters use waves 2, 4, and 8.

## State

Per-player Wish state stores:

```gdscript
{
    "phase": WISH_AVAILABLE,
    "wish_count": 0,
    "pending_item_ids": [],
    "discount_queue": [],
    "layout_version": 3,
    "resource_version": 1,
}
```

The queue survives leaving the shop and save/resume. It clears only after a
successful reroll inserts the items.

The shared Crooked/Wish wave state stores queued and active Calamities,
temporary enemy Health and Damage, per-player XP Gain and Luck, guaranteed
crate drops, and the exact effect values to restore. Duplicate Hunter entries
remain distinct, allowing Wish You Were Here to stack with a Crooked Hunter.

## Shop hooks

- `BaseShop.fill_shop_items`: preserve locked cards, run vanilla generation,
  then replace reserved unlocked results with queued items.
- `BaseShop._on_RerollButton_pressed`: refresh Wish UI after native reroll.
- `BaseShop.on_shop_item_bought`: keep native purchase handling, then refresh
  Wish state, Lamp limits, and cursed-Lamp prices.
- `ShopItem.change_lock_status`: refuse only locks that would consume a slot
  already reserved by a queued Wish.

Confirmation is transactional: revalidate the item and slot, verify resources,
charge once, then append the item ID. Failed or cancelled confirmations charge
nothing.

## Cursed Magic Lamp

A cursed Lamp queues one percentage discount for the next paid shop-card
purchase. Wish fees, rerolls, steals, and upgrades do not consume it. The
displayed card price is recalculated from the same value the shop charges.

## Unlocks and compatibility

Winning as Djinn unlocks Magic Lamp globally. Winning as Shaman unlocks
Monkey's Paw globally. Both characters inherit only the profile's selectable
Danger ceiling, not victories.

The current local target is Brotato `1.1.12.0.beta-3` with ModLoader `6.3.0`.

## Wish item catalogue

- **Wish for Friends (Rare):** queue Brotato's native Horde rules for the next
  wave. A cursed copy grants its owner +10% XP Gain during that Horde only.
- **Wish It Away (Rare):** gain 1 Ban; the next wave gives enemies +10% Health. A
  cursed copy grants 2 Bans with the same consequence.
- **Wish You Were Here (Rare):** an additional Elite appears next wave and
  drops a guaranteed crate. A cursed copy guarantees a second normal crate
  during the same wave.
- **Wish for Treasure (Rare):** guarantee a crate drop during the next wave,
  while enemies deal +10% Damage. A cursed copy guarantees 2 crates.
- **Wish for Harvest (Legendary):** permanently gain +80 Harvesting; the next
  wave gives enemies +15% Health. A cursed copy permanently grants +120
  Harvesting. The original `item_wish_for_quality` ID is retained for saved
  inventories and unlocks; shop quality rewards are no longer queued or applied.
- **Wish for Fortune (Rare):** permanently gain +25 Luck while enemies deal
  +10% Damage during the next wave. A cursed copy permanently grants +40 Luck.
- **Wish for Knowledge (Uncommon):** permanently gain +30% XP Gain while the
  total number of enemies permanently increases by 2%. A cursed copy grants
  +40% XP Gain with the same consequence.
