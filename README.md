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

Wished items appear in normal shop slots on the next reroll. They retain their
normal price and ordinary buy, lock, and reroll behaviour. Multiple Wishes can
be queued, while item tiers and bans remain respected.

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

## Artwork and contributions

All custom artwork in Wish was AI-generated. I'm a software engineer and a
terrible, terrible artist, so human cleanup, redraws, and replacement artwork
would be hugely appreciated.

If you would like to improve the artwork—or contribute code—please open an
issue or pull request in this
[public repository](https://github.com/matthewrdev/brotato-mods).
