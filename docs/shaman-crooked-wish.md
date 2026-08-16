# Shaman and Crooked Wish

Crooked Wish shares Djinn's normal-slot delivery queue but consumes a Monkey's
Paw charge instead of materials or a Wish resource. Every use also queues one
distinct Calamity for the next wave.

Shaman starts with +5 Harvesting, Monkey's Paw, and a Wand in addition to the
weapon selected by the player. Shaman does not start with Snake.

Run state stores Paw charges, queued items, and queued/active Calamities.
Calamities are activated before the retry snapshot so retries do not duplicate
effects or rewards.

- **Hunter:** additional elite; normal crate reward.
- **Horde:** native Horde wave.
- **Night:** fog plus +10% enemy speed.
- **Frenzy:** native environmental projectiles.
- **Famine:** 50% of fruit drops become poisoned fruit.

All temporary changes are restored at wave end.
