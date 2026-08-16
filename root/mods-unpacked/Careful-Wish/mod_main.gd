extends Node

const MOD_ID = "Careful-Wish"

var mod_dir = ""


func _init() -> void:
	mod_dir = ModLoaderMod.get_unpacked_dir() + MOD_ID + "/"
	_install_translations()
	ModLoaderMod.install_script_extension(mod_dir + "extensions/singletons/item_service.gd")
	ModLoaderMod.install_script_extension(mod_dir + "extensions/singletons/run_data.gd")
	ModLoaderMod.install_script_extension(mod_dir + "extensions/main.gd")
	ModLoaderMod.install_script_extension(mod_dir + "extensions/ui/menus/shop/shop_item.gd")
	ModLoaderMod.install_script_extension(mod_dir + "extensions/ui/menus/shop/base_shop.gd")
	ModLoaderLog.info("Installed Wish extensions", MOD_ID)


func _ready() -> void:
	ModLoaderLog.info("Wish ready", MOD_ID)


func _install_translations() -> void:
	var translation = Translation.new()
	translation.locale = "en"

	var messages = {
		"CHARACTER_DJINN": "Djinn",
		"CHARACTER_SHAMAN": "Shaman",
		"ITEM_MAGIC_LAMP": "Magic Lamp",
		"ITEM_MONKEYS_PAW": "Monkey's Paw",
		"ITEM_WISH_RESOURCE": "Wish",
		"WISH_RESOURCE_EFFECT": "Consumed when making a Wish",
		"WISH_CHARACTER_EFFECT": "Starts with 3 Wishes\nWishes demand materials",
		"WISH_LAMP_EFFECT": "+{0} Wish\nGrants access to Wish",
		"WISH_CURSED_LAMP_EFFECT": "The next purchased shop item costs {0}% less",
		"WISH_ACTION": "Make a Wish",
		"WISH_ACTION_COMPACT": "Wish — {0}",
		"WISH_PICKER_TITLE": "Choose an item for the next reroll",
		"WISH_SEARCH": "Search items...",
		"WISH_CHOOSE": "Choose an item",
		"WISH_CONFIRM": "Wish for {0} — {1} materials + 1 Wish",
		"WISH_CANCEL": "Cancel",
		"WISH_COST": "Cost: {0} materials",
		"WISH_WISH_FEE": "Wish fee: {0} materials + 1 Wish",
		"WISH_ESTIMATED_ITEM_COST": "Estimated item cost on the next reroll: {0} materials",
		"WISH_NEED_MATERIALS": "Need {0} materials",
		"WISH_NO_RESOURCES": "No Wishes remaining",
		"WISH_RESOURCE_COUNT": "Wishes: {0}",
		"WISH_QUEUED": "Wished for {0}\nIt will appear on the next reroll",
		"WISH_COMING_NEXT": "Coming on the next reroll",
		"WISH_AGAIN_ONE_COMPACT": "Wish again — {0}\nNext: {1} ~{2}",
		"WISH_AGAIN_MANY_COMPACT": "Wish again — {0}\nNext: {1} ~{2} +{3}",
		"WISH_QUEUE_ITEM": "Next reroll: {0} — estimated {1}",
		"WISH_NO_REROLL_SLOTS": "No unlocked shop slots remain for the next reroll",
		"WISH_QUEUE_MIGRATING": "Queued Wishes will be moved to the next reroll",
		"WISH_NEXT_WITH_COST_COMPACT": "Next: {0}\nEstimated: {1}",
		"WISH_ITEM_PREVIEW": "{0}\n{1}",
		"WISH_DELIVERY_READY": "Wish delivery",
		"WISH_BUY_COMPACT": "Buy {0}\n{1}",
		"WISH_FULFILLED": "Wish fulfilled\nAvailable again next shop",
		"WISH_FULFILLED_COMPACT": "Wish fulfilled",
		"WISH_UNAVAILABLE": "The wished item is no longer eligible",
		"WISH_UNAVAILABLE_COMPACT": "Wish unavailable",
		"WISH_NO_NEXT_SHOP": "No later shop is available",
		"WISH_SELECTION_INVALID": "That item is no longer eligible",
		"WISH_DELIVERY_SHOP": "Wish is resting during delivery",
		"WISH_TIER_0": "Common",
		"WISH_TIER_1": "Uncommon",
		"WISH_TIER_2": "Rare",
		"WISH_TIER_3": "Legendary",
		"WISH_UNLOCKS_NEXT_WAVE": "Unlocks next wave",
		"WISH_UNLOCKS_IN_WAVES": "Unlocks in {0} waves",
		"CROOKED_CHARACTER_EFFECT": "Starts with Monkey's Paw\nCrooked Wishes come with a catch",
		"CROOKED_PAW_EFFECT": "Grants {0} Crooked Wishes",
		"CROOKED_ACTION_COMPACT": "Crooked Wish — {0}",
		"CROOKED_PICKER_TITLE": "Choose an item and tempt fate",
		"CROOKED_CONFIRM": "Crooked Wish for {0} — curl 1 finger",
		"CROOKED_CHARGES": "Paw fingers: {0}",
		"CROOKED_CONSEQUENCE": "The item keeps its normal price. A random Calamity affects the next wave.",
		"CROOKED_NO_CHARGES": "The Paw has no extended fingers remaining",
		"CROOKED_BADGE": "Next wave: {0}",
		"CROOKED_REVEAL_TITLE": "A Crooked Wish",
		"CROOKED_REVEAL": "A finger curls. {0} awaits.",
		"CALAMITY_HUNTER_NAME": "The Hunter",
		"CALAMITY_HUNTER_DESC": "An additional elite hunts you and drops one normal crate.",
		"CALAMITY_HORDE_NAME": "The Horde",
		"CALAMITY_HORDE_DESC": "The next wave uses Brotato's native Horde rules.",
		"CALAMITY_NIGHT_NAME": "The Night",
		"CALAMITY_NIGHT_DESC": "Darkness substantially reduces the visible area and enemies move 10% faster.",
		"CALAMITY_FRENZY_NAME": "The Frenzy",
		"CALAMITY_FRENZY_DESC": "Environmental projectiles persist throughout the wave.",
		"CALAMITY_FAMINE_NAME": "The Famine",
		"CALAMITY_FAMINE_DESC": "Half of all fruit drops become poisoned fruit."
	}

	for key in messages:
		translation.add_message(key, messages[key])
	TranslationServer.add_translation(translation)
