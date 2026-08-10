# Wish implementation notes

## Rules

- Wish is an external shop action; all four shop cards remain native.
- A Wish costs 1 Wish resource plus
  `30 + 4 × (wave - 1) + 3 × wishes used` materials.
- Multiple items may be queued for the next successful reroll, limited by
  unlocked shop slots.
- Queued items become ordinary cards with native prices and behaviour.
- Eligibility respects unlocks, bans, character exclusions, ownership caps,
  endless restrictions, and removed shop groups.
- Magic Lamp is never wishable. It is repeatable across a run, limited to one
  purchase per shop visit, and cannot be locked or banned.

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
