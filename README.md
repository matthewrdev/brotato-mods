# Wish

Wish is a Brotato mod built around getting what you want from the shop—and
paying the price for it.

## What it adds

- **Djinn:** makes Wishes by spending Wish resources and materials.
- **Magic Lamp:** a repeatable Legendary item that grants another Wish.
- **Shaman:** makes Crooked Wishes that guarantee an item but bring a one-wave
  Calamity.
- **Monkey's Paw:** Shaman's unique Legendary item. It begins with three
  extended fingers, and each Crooked Wish curls one.
- **Seven Wish items:** ask for company, bans, an Elite, crates, item quality,
  Luck, or permanent XP Gain. Every reward has a price.

Wished items appear in normal shop slots on the next reroll. They retain their
normal price and ordinary buy, lock, and reroll behaviour. Multiple Wishes can
be queued, while item tiers and bans remain respected.

## Characters and wishing

### Djinn

Djinn starts with three Wishes and a Lamp-themed shop action. Spend one Wish
and some materials, search the eligible item pool, then choose the item that
will occupy a normal shop slot on the next reroll. Djinn leans toward
Harvesting, XP Gain, and Elemental weapons.

### Shaman

Shaman starts with Monkey's Paw. Each of its three extended fingers can make a
Crooked Wish: the chosen item is still guaranteed on the next reroll, but a
random Calamity is also queued for the next wave. The Paw's icon changes as its
fingers curl.

Calamities include an additional Elite, a Horde, darkness with faster enemies,
persistent environmental projectiles, and poisoned fruit. They last for one
wave and survive save/resume.

## Wish items

Most Wish items are consumed when their promised wave begins, allowing them to
appear again later in the run. Cursed copies improve the reward without making
the listed price worse.

- **Wish for Friends** (Rare): the next wave is a Horde. A cursed copy grants
  +10% XP Gain during that Horde.
- **Wish It Away** (Rare): gain a Ban token; the next wave's enemies have +10%
  Health. A cursed copy grants two Ban tokens.
- **Wish You Were Here** (Rare): an additional Elite appears next wave with a
  guaranteed crate. A cursed copy guarantees a second crate.
- **Wish for Treasure** (Rare): the next wave drops a guaranteed crate while
  enemies deal +10% Damage. A cursed copy guarantees two crates.
- **Wish for Quality** (Legendary): an unlocked slot in the shop after the next
  wave is at least Rare, while that wave's enemies have +15% Health. A cursed
  copy upgrades two slots.
- **Wish for Fortune** (Rare): gain +25 Luck for the next wave while enemies
  deal +10% Damage. A cursed copy grants +40 Luck.
- **Wish for Knowledge** (Uncommon): permanently gain +15% XP Gain while
  enemies permanently gain +5% Health. A cursed copy grants +25% XP Gain with
  the same consequence.

Magic Lamp becomes available to other characters after winning as Djinn.
Monkey's Paw becomes available to other characters after winning as Shaman.

## Repository layout

- [`root/mods-unpacked/Careful-Wish`](root/mods-unpacked/Careful-Wish): playable
  mod source and runtime assets
- [`docs`](docs): mechanics and implementation notes
- [`assets/final`](assets/final): canonical artwork
- [`workshop`](workshop): Steam Workshop description, preview, and release
  checklist
- [`TESTING.md`](TESTING.md): smoke-test checklist

## Build and test

```sh
./scripts/package_mod.sh
./scripts/install_local.sh
```

The build produces `dist/Wish-<version>.zip`, with the version read from the
manifest. Fully restart Brotato after installing the mod locally.

The current target is Brotato `1.1.12.0.beta-3` with ModLoader `6.3.0`, and
Abyssal Terrors is required. See [`TESTING.md`](TESTING.md) for the full smoke
test.

## Steam Workshop

The release-ready Workshop description, preview image, and publishing checklist
live in [`workshop`](workshop). Build the archive first, then use Brotato's
included Godot Workshop Utility to create or update the Workshop item with the
contents of `root/mods-unpacked/Careful-Wish`.

## Artwork and contributions

All custom artwork in Wish was AI-generated. I'm a software engineer and a
terrible, terrible artist, so human cleanup, redraws, and replacement artwork
would be hugely appreciated.

If you would like to improve the artwork—or contribute code—please open an
issue or pull request in this
[public repository](https://github.com/matthewrdev/brotato-mods).
