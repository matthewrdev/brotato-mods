extends "res://singletons/item_service.gd"

const MOD_DIR = "res://mods-unpacked/Careful-Wish/"
const DJINN_ID = "character_djinn"
const SHAMAN_ID = "character_shaman"
const LAMP_ID = "item_magic_lamp"
const PAW_ID = "item_monkeys_paw"
const COMPANY_WISH_ID = "item_wish_for_company"
const WISH_IT_AWAY_ID = "item_wish_it_away"
const WISH_YOU_WERE_HERE_ID = "item_wish_you_were_here"
const WISH_FOR_TREASURE_ID = "item_wish_for_treasure"
# Retain the original ID for saved inventories and unlocks.
const WISH_FOR_QUALITY_ID = "item_wish_for_quality"
const WISH_FOR_FORTUNE_ID = "item_wish_for_fortune"
const WISH_FOR_KNOWLEDGE_ID = "item_wish_for_knowledge"
const WISH_RESOURCE_ID = "item_wish_resource"
const PLACEHOLDER_ID = "item_wish_empty_slot"
const FRUIT_ID = "consumable_fruit"
const POISONED_FRUIT_PATH = "res://dlcs/dlc_1/consumables/poisoned_fruit_data.tres"
const CHALLENGE_ID = "chal_djinn"
const SHAMAN_CHALLENGE_ID = "chal_shaman"
const BASE_CURSED_DISCOUNT = 20
const MAX_CURSED_DISCOUNT = 90
const DJINN_STARTING_WEAPON_IDS = [
	"weapon_wand_1",
	"weapon_torch_1",
	"weapon_plank_1",
	"weapon_taser_1",
	"weapon_lightning_shiv_1",
	"weapon_icicle_1",
	"weapon_smg_1",
	"weapon_double_barrel_shotgun_1"
]
const SHAMAN_STARTING_WEAPON_IDS = [
	"weapon_wand_1",
	"weapon_torch_1",
	"weapon_taser_1",
	"weapon_lightning_shiv_1",
	"weapon_icicle_1",
	"weapon_plank_1",
	"weapon_screwdriver_1",
	"weapon_wrench_1"
]

var wish_djinn_data = null
var wish_shaman_data = null
var wish_lamp_data = null
var wish_paw_data = null
var wish_for_company_data = null
var wish_it_away_data = null
var wish_you_were_here_data = null
var wish_for_treasure_data = null
var wish_for_quality_data = null
var wish_for_fortune_data = null
var wish_for_knowledge_data = null
var wish_resource_data = null
var wish_placeholder_data = null
var wish_challenge_data = null
var wish_shaman_challenge_data = null
var wish_lamp_active_icon = null
var wish_lamp_used_icon = null
var wish_poisoned_fruit_data = null
var wish_paw_icons = []


func _ready() -> void:
	_wish_install_content()
	# ContentLoader reloads ProgressData later in the same ready pass. Defer the
	# default unlocks so the saved profile cannot turn new content back into a
	# padlock.
	call_deferred("_wish_unlock_content_after_profile_load")


func _wish_unlock_content_after_profile_load() -> void:
	if wish_djinn_data == null:
		wish_djinn_data = _wish_find_by_id(characters, DJINN_ID)
	if wish_shaman_data == null:
		wish_shaman_data = _wish_find_by_id(characters, SHAMAN_ID)
	if wish_for_company_data == null:
		wish_for_company_data = _wish_find_by_id(items, COMPANY_WISH_ID)
	wish_it_away_data = _wish_find_by_id(items, WISH_IT_AWAY_ID)
	wish_you_were_here_data = _wish_find_by_id(items, WISH_YOU_WERE_HERE_ID)
	wish_for_treasure_data = _wish_find_by_id(items, WISH_FOR_TREASURE_ID)
	wish_for_quality_data = _wish_find_by_id(items, WISH_FOR_QUALITY_ID)
	wish_for_fortune_data = _wish_find_by_id(items, WISH_FOR_FORTUNE_ID)
	wish_for_knowledge_data = _wish_find_by_id(items, WISH_FOR_KNOWLEDGE_ID)
	var default_items = [
		wish_for_company_data,
		wish_it_away_data,
		wish_you_were_here_data,
		wish_for_treasure_data,
		wish_for_quality_data,
		wish_for_fortune_data,
		wish_for_knowledge_data
	]
	if wish_djinn_data == null or wish_shaman_data == null or default_items.has(null):
		push_error("Wish could not find its default content after registration")
		return

	var changed = false
	for character in [wish_djinn_data, wish_shaman_data]:
		if not ProgressData.characters_unlocked.has(character.my_id_hash):
			ProgressData.characters_unlocked.push_back(character.my_id_hash)
			changed = true
	for item in default_items:
		if not ProgressData.items_unlocked.has(item.my_id_hash):
			ProgressData.items_unlocked.push_back(item.my_id_hash)
			changed = true

	if _wish_sync_character_difficulty_unlocks(DJINN_ID):
		changed = true
	if _wish_sync_character_difficulty_unlocks(SHAMAN_ID):
		changed = true

	if changed:
		ProgressData.save()
		ModLoaderLog.info("Unlocked Djinn, Shaman, and Wish items and synced available Danger modes", "Careful-Wish")


func _wish_sync_djinn_difficulty_unlocks() -> bool:
	return _wish_sync_character_difficulty_unlocks(DJINN_ID)


func _wish_sync_character_difficulty_unlocks(character_id: String) -> bool:
	# Dynamic characters receive a fresh difficulty record with only Danger 0.
	# Danger availability is profile-wide, so copy each zone's selectable ceiling
	# while deliberately leaving Djinn's completion scores at their defaults.
	var djinn_difficulty = null
	var selectable_by_zone = {}

	for character_difficulty in ProgressData.difficulties_unlocked:
		if character_difficulty.character_id == character_id:
			djinn_difficulty = character_difficulty
			continue

		for zone_difficulty in character_difficulty.zones_difficulty_info:
			var current_ceiling = selectable_by_zone.get(zone_difficulty.zone_id, 0)
			selectable_by_zone[zone_difficulty.zone_id] = max(
				current_ceiling,
				zone_difficulty.max_selectable_difficulty
			)

	for zone in ZoneService.zones:
		if zone.unlocked_by_default and not selectable_by_zone.has(zone.my_id):
			selectable_by_zone[zone.my_id] = 0

	var changed = false
	if djinn_difficulty == null:
		djinn_difficulty = CharacterDifficultyInfo.new(character_id)
		ProgressData.difficulties_unlocked.push_back(djinn_difficulty)
		changed = true

	for zone_id in selectable_by_zone:
		var djinn_zone_difficulty = null
		for zone_difficulty in djinn_difficulty.zones_difficulty_info:
			if zone_difficulty.zone_id == zone_id:
				djinn_zone_difficulty = zone_difficulty
				break

		if djinn_zone_difficulty == null:
			djinn_zone_difficulty = ZoneDifficultyInfo.new(zone_id)
			djinn_difficulty.zones_difficulty_info.push_back(djinn_zone_difficulty)
			changed = true

		var selectable_ceiling = selectable_by_zone[zone_id] as int
		if djinn_zone_difficulty.max_selectable_difficulty < selectable_ceiling:
			djinn_zone_difficulty.max_selectable_difficulty = selectable_ceiling
			changed = true

	return changed


func _wish_install_content() -> void:
	if _wish_find_by_id(characters, DJINN_ID) != null and _wish_find_by_id(characters, SHAMAN_ID) != null:
		wish_djinn_data = _wish_find_by_id(characters, DJINN_ID)
		wish_shaman_data = _wish_find_by_id(characters, SHAMAN_ID)
		wish_lamp_data = _wish_find_by_id(items, LAMP_ID)
		wish_paw_data = _wish_find_by_id(items, PAW_ID)
		wish_for_company_data = _wish_find_by_id(items, COMPANY_WISH_ID)
		wish_it_away_data = _wish_find_by_id(items, WISH_IT_AWAY_ID)
		wish_you_were_here_data = _wish_find_by_id(items, WISH_YOU_WERE_HERE_ID)
		wish_for_treasure_data = _wish_find_by_id(items, WISH_FOR_TREASURE_ID)
		wish_for_quality_data = _wish_find_by_id(items, WISH_FOR_QUALITY_ID)
		wish_for_fortune_data = _wish_find_by_id(items, WISH_FOR_FORTUNE_ID)
		wish_for_knowledge_data = _wish_find_by_id(items, WISH_FOR_KNOWLEDGE_ID)
		wish_resource_data = _wish_find_by_id(items, WISH_RESOURCE_ID)
		wish_placeholder_data = _wish_find_by_id(items, PLACEHOLDER_ID)
		return

	wish_lamp_active_icon = _wish_load_png(MOD_DIR + "assets/wishmod_magic_lamp.png")
	wish_lamp_used_icon = _wish_load_png(MOD_DIR + "assets/wishmod_magic_lamp_used.png")
	var djinn_icon = _wish_load_png(MOD_DIR + "assets/wishmod_djinn.png")
	var djinn_face_texture = _wish_load_png(MOD_DIR + "assets/wishmod_djinn_face.png")
	var djinn_hat_texture = _wish_load_png(MOD_DIR + "assets/wishmod_djinn_hat.png")
	var shaman_icon = _wish_load_png(MOD_DIR + "assets/wishmod_shaman.png")
	var shaman_face_texture = _wish_load_png(MOD_DIR + "assets/wishmod_shaman_face.png")
	var shaman_hat_texture = _wish_load_png(MOD_DIR + "assets/wishmod_shaman_hat.png")
	var wish_for_friends_icon = _wish_load_png(MOD_DIR + "assets/wishmod_wish_for_friends.png")
	var wish_it_away_icon = _wish_load_png(MOD_DIR + "assets/wishmod_wish_it_away.png")
	var wish_you_were_here_icon = _wish_load_png(MOD_DIR + "assets/wishmod_wish_you_were_here.png")
	var wish_for_treasure_icon = _wish_load_png(MOD_DIR + "assets/wishmod_wish_for_treasure.png")
	var wish_for_quality_icon = _wish_load_png(MOD_DIR + "assets/wishmod_wish_for_quality.png")
	var wish_for_fortune_icon = _wish_load_png(MOD_DIR + "assets/wishmod_wish_for_fortune.png")
	var wish_for_knowledge_icon = _wish_load_png(MOD_DIR + "assets/wishmod_wish_for_knowledge.png")
	for paw_charges in [0, 1, 2, 3]:
		wish_paw_icons.push_back(_wish_load_png(MOD_DIR + "assets/wishmod_monkeys_paw_" + str(paw_charges) + ".png"))

	wish_lamp_data = ItemData.new()
	wish_lamp_data.my_id = LAMP_ID
	wish_lamp_data.unlocked_by_default = false
	wish_lamp_data.can_be_looted = true
	wish_lamp_data.icon = wish_lamp_active_icon
	wish_lamp_data.name = "ITEM_MAGIC_LAMP"
	wish_lamp_data.tier = ItemParentData.Tier.LEGENDARY
	wish_lamp_data.value = 100
	wish_lamp_data.effects = [_wish_text_effect("WISH_LAMP_EFFECT", 1)]
	wish_lamp_data.tracking_text = ""
	wish_lamp_data.is_lockable = false
	wish_lamp_data.max_nb = -1
	wish_lamp_data.item_appearances = []
	wish_lamp_data.tags = []
	wish_lamp_data._generate_hashes()
	items.push_back(wish_lamp_data)

	wish_paw_data = ItemData.new()
	wish_paw_data.my_id = PAW_ID
	wish_paw_data.unlocked_by_default = false
	wish_paw_data.can_be_looted = true
	wish_paw_data.icon = wish_paw_icons[3]
	wish_paw_data.name = "ITEM_MONKEYS_PAW"
	wish_paw_data.tier = ItemParentData.Tier.LEGENDARY
	wish_paw_data.value = 100
	wish_paw_data.effects = [_wish_text_effect("CROOKED_PAW_EFFECT", 3)]
	wish_paw_data.tracking_text = ""
	wish_paw_data.is_lockable = true
	wish_paw_data.max_nb = 1
	wish_paw_data.item_appearances = []
	wish_paw_data.tags = ["stat_curse", "stat_elemental_damage", "stat_lifesteal"]
	wish_paw_data._generate_hashes()
	items.push_back(wish_paw_data)

	wish_for_company_data = ItemData.new()
	wish_for_company_data.my_id = COMPANY_WISH_ID
	wish_for_company_data.unlocked_by_default = true
	wish_for_company_data.can_be_looted = true
	wish_for_company_data.icon = wish_for_friends_icon
	wish_for_company_data.name = "ITEM_WISH_FOR_COMPANY"
	wish_for_company_data.tier = ItemParentData.Tier.RARE
	wish_for_company_data.value = 50
	wish_for_company_data.effects = [_wish_text_effect("WISH_FOR_COMPANY_EFFECT", 0)]
	wish_for_company_data.tracking_text = ""
	wish_for_company_data.is_lockable = true
	wish_for_company_data.max_nb = 1
	wish_for_company_data.item_appearances = []
	wish_for_company_data.tags = []
	wish_for_company_data._generate_hashes()
	items.push_back(wish_for_company_data)

	wish_it_away_data = _wish_create_item(
		WISH_IT_AWAY_ID,
		"ITEM_WISH_IT_AWAY",
		wish_it_away_icon,
		ItemParentData.Tier.RARE,
		50,
		[_wish_text_effect("WISH_IT_AWAY_EFFECT", 1)]
	)

	wish_you_were_here_data = _wish_create_item(
		WISH_YOU_WERE_HERE_ID,
		"ITEM_WISH_YOU_WERE_HERE",
		wish_you_were_here_icon,
		ItemParentData.Tier.RARE,
		50,
		[_wish_text_effect("WISH_YOU_WERE_HERE_EFFECT", 1)]
	)

	wish_for_treasure_data = _wish_create_item(
		WISH_FOR_TREASURE_ID,
		"ITEM_WISH_FOR_TREASURE",
		wish_for_treasure_icon,
		ItemParentData.Tier.RARE,
		50,
		[_wish_text_effect("WISH_FOR_TREASURE_EFFECT", 1)]
	)

	wish_for_quality_data = _wish_create_item(
		WISH_FOR_QUALITY_ID,
		"ITEM_WISH_FOR_QUALITY",
		wish_for_quality_icon,
		ItemParentData.Tier.LEGENDARY,
		90,
		[
			_wish_labeled_stat_effect(
				"stat_harvesting",
				"WISH_FOR_QUALITY_EFFECT",
				80,
				Effect.Sign.POSITIVE
			)
		]
	)

	wish_for_fortune_data = _wish_create_item(
		WISH_FOR_FORTUNE_ID,
		"ITEM_WISH_FOR_FORTUNE",
		wish_for_fortune_icon,
		ItemParentData.Tier.RARE,
		50,
		[
			_wish_labeled_stat_effect(
				"stat_luck",
				"WISH_FOR_FORTUNE_EFFECT",
				25,
				Effect.Sign.POSITIVE
			)
		]
	)

	wish_for_knowledge_data = _wish_create_item(
		WISH_FOR_KNOWLEDGE_ID,
		"ITEM_WISH_FOR_KNOWLEDGE",
		wish_for_knowledge_icon,
		ItemParentData.Tier.UNCOMMON,
		35,
		[
			_wish_stat_effect("xp_gain", 30),
			_wish_labeled_stat_effect(
				"number_of_enemies",
				"",
				2,
				Effect.Sign.NEGATIVE
			)
		]
	)

	wish_resource_data = ItemData.new()
	wish_resource_data.my_id = WISH_RESOURCE_ID
	wish_resource_data.unlocked_by_default = false
	wish_resource_data.can_be_looted = false
	wish_resource_data.icon = wish_lamp_active_icon
	wish_resource_data.name = "ITEM_WISH_RESOURCE"
	wish_resource_data.tier = ItemParentData.Tier.COMMON
	wish_resource_data.value = 0
	wish_resource_data.effects = [_wish_text_effect("WISH_RESOURCE_EFFECT", 0)]
	wish_resource_data.tracking_text = ""
	wish_resource_data.is_lockable = false
	wish_resource_data.max_nb = -1
	wish_resource_data.item_appearances = []
	wish_resource_data.tags = []
	wish_resource_data._generate_hashes()
	items.push_back(wish_resource_data)

	wish_placeholder_data = ItemData.new()
	wish_placeholder_data.my_id = PLACEHOLDER_ID
	wish_placeholder_data.unlocked_by_default = false
	wish_placeholder_data.can_be_looted = false
	wish_placeholder_data.name = ""
	wish_placeholder_data.tier = ItemParentData.Tier.COMMON
	wish_placeholder_data.value = 0
	wish_placeholder_data.effects = []
	wish_placeholder_data.is_lockable = false
	wish_placeholder_data.max_nb = 0
	wish_placeholder_data.item_appearances = []
	wish_placeholder_data.tags = []
	wish_placeholder_data._generate_hashes()
	items.push_back(wish_placeholder_data)

	wish_djinn_data = CharacterData.new()
	wish_djinn_data.my_id = DJINN_ID
	wish_djinn_data.unlocked_by_default = true
	wish_djinn_data.can_be_looted = true
	wish_djinn_data.icon = djinn_icon
	wish_djinn_data.name = "CHARACTER_DJINN"
	wish_djinn_data.tier = ItemParentData.Tier.COMMON
	wish_djinn_data.value = 1
	wish_djinn_data.effects = [
		_wish_stat_effect("stat_harvesting", 7),
		_wish_stat_gain_effect("stat_harvesting", 15),
		_wish_stat_effect("xp_gain", 15),
		_wish_starting_item_effect(WISH_RESOURCE_ID, 3),
		_wish_text_effect("WISH_CHARACTER_EFFECT", 0)
	]
	wish_djinn_data.max_nb = -1
	var djinn_face_appearance = ItemAppearanceData.new()
	djinn_face_appearance.sprite = djinn_face_texture
	djinn_face_appearance.position = ItemAppearanceData.Position.EYES
	djinn_face_appearance.display_priority = ItemAppearanceData.Priority.VERY_LOW
	djinn_face_appearance.depth = 500.0
	djinn_face_appearance.is_character_appearance = true

	var djinn_hat_appearance = ItemAppearanceData.new()
	djinn_hat_appearance.sprite = djinn_hat_texture
	djinn_hat_appearance.position = ItemAppearanceData.Position.HAT
	djinn_hat_appearance.display_priority = ItemAppearanceData.Priority.HIGH
	djinn_hat_appearance.depth = 1000.0
	djinn_hat_appearance.is_character_appearance = true
	wish_djinn_data.item_appearances = [djinn_face_appearance, djinn_hat_appearance]
	wish_djinn_data.tags = []
	wish_djinn_data.wanted_tags = ["stat_harvesting", "xp_gain"]
	wish_djinn_data.banned_item_groups = []
	wish_djinn_data.banned_items = []
	wish_djinn_data.banned_upgrades = []
	wish_djinn_data.starting_items = []
	wish_djinn_data.starting_weapons = _wish_get_djinn_starting_weapons()
	wish_djinn_data._generate_hashes()
	characters.push_back(wish_djinn_data)

	wish_shaman_data = CharacterData.new()
	wish_shaman_data.my_id = SHAMAN_ID
	wish_shaman_data.unlocked_by_default = true
	wish_shaman_data.can_be_looted = true
	wish_shaman_data.icon = shaman_icon
	wish_shaman_data.name = "CHARACTER_SHAMAN"
	wish_shaman_data.tier = ItemParentData.Tier.COMMON
	wish_shaman_data.value = 1
	wish_shaman_data.effects = [
		_wish_stat_effect("stat_curse", 5),
		_wish_stat_effect("stat_harvesting", 5),
		_wish_stat_on_level_up_effect("stat_curse", 1),
		_wish_stat_gain_effect("stat_elemental_damage", 15),
		_wish_stat_gain_effect("stat_lifesteal", 15),
		_wish_stat_gain_effect("stat_melee_damage", -50),
		_wish_stat_gain_effect("stat_ranged_damage", -50),
		_wish_starting_weapon_effect("weapon_wand_1"),
		_wish_starting_item_effect(PAW_ID, 1),
		_wish_text_effect("CROOKED_CHARACTER_EFFECT", 0)
	]
	wish_shaman_data.max_nb = -1
	var shaman_face_appearance = ItemAppearanceData.new()
	shaman_face_appearance.sprite = shaman_face_texture
	shaman_face_appearance.position = ItemAppearanceData.Position.EYES
	shaman_face_appearance.display_priority = ItemAppearanceData.Priority.VERY_LOW
	shaman_face_appearance.depth = 500.0
	shaman_face_appearance.is_character_appearance = true
	var shaman_hat_appearance = ItemAppearanceData.new()
	shaman_hat_appearance.sprite = shaman_hat_texture
	shaman_hat_appearance.position = ItemAppearanceData.Position.HAT
	shaman_hat_appearance.display_priority = ItemAppearanceData.Priority.HIGH
	shaman_hat_appearance.depth = 1000.0
	shaman_hat_appearance.is_character_appearance = true
	wish_shaman_data.item_appearances = [shaman_face_appearance, shaman_hat_appearance]
	wish_shaman_data.tags = []
	wish_shaman_data.wanted_tags = ["stat_curse", "stat_elemental_damage", "stat_lifesteal"]
	wish_shaman_data.banned_item_groups = []
	wish_shaman_data.banned_items = []
	wish_shaman_data.banned_upgrades = []
	wish_shaman_data.starting_items = []
	wish_shaman_data.starting_weapons = _wish_get_starting_weapons(SHAMAN_STARTING_WEAPON_IDS)
	wish_shaman_data._generate_hashes()
	characters.push_back(wish_shaman_data)

	wish_challenge_data = ChallengeData.new()
	wish_challenge_data.my_id = CHALLENGE_ID
	wish_challenge_data.unlocked_by_default = false
	wish_challenge_data.can_be_looted = false
	wish_challenge_data.icon = djinn_icon
	wish_challenge_data.name = "CHARACTER_DJINN"
	wish_challenge_data.description = "CHAL_CHARACTER_DESC"
	wish_challenge_data.reward_type = ChallengeData.RewardType.ITEM
	wish_challenge_data.reward = wish_lamp_data
	wish_challenge_data.effects = []
	wish_challenge_data._generate_hashes()
	ChallengeService.challenges.push_back(wish_challenge_data)
	ChallengeService.hash_to_id[wish_challenge_data.my_id_hash] = CHALLENGE_ID

	wish_shaman_challenge_data = ChallengeData.new()
	wish_shaman_challenge_data.my_id = SHAMAN_CHALLENGE_ID
	wish_shaman_challenge_data.unlocked_by_default = false
	wish_shaman_challenge_data.can_be_looted = false
	wish_shaman_challenge_data.icon = shaman_icon
	wish_shaman_challenge_data.name = "CHARACTER_SHAMAN"
	wish_shaman_challenge_data.description = "CHAL_CHARACTER_DESC"
	wish_shaman_challenge_data.reward_type = ChallengeData.RewardType.ITEM
	wish_shaman_challenge_data.reward = wish_paw_data
	wish_shaman_challenge_data.effects = []
	wish_shaman_challenge_data._generate_hashes()
	ChallengeService.challenges.push_back(wish_shaman_challenge_data)
	ChallengeService.hash_to_id[wish_shaman_challenge_data.my_id_hash] = SHAMAN_CHALLENGE_ID

	ModLoaderLog.info("Registered Djinn, Shaman, Magic Lamp, Monkey's Paw, seven Wish items, and challenges", "Careful-Wish")


func apply_item_effect_modifications(item: ItemParentData, player_index: int) -> ItemParentData:
	var result = .apply_item_effect_modifications(item, player_index)
	if result == null or not result.is_cursed:
		return result

	if result.my_id == LAMP_ID:
		var discount = wish_get_lamp_discount(result)
		for effect in result.effects:
			if effect.text_key == "WISH_CURSED_LAMP_EFFECT":
				effect.value = discount
				return result
		result.effects.push_back(_wish_text_effect("WISH_CURSED_LAMP_EFFECT", discount))
	elif result.my_id == COMPANY_WISH_ID:
		for effect in result.effects:
			if effect.text_key == "WISH_FOR_COMPANY_CURSED_EFFECT":
				return result
		result.effects.push_back(_wish_text_effect("WISH_FOR_COMPANY_CURSED_EFFECT", 10))
	elif result.my_id == WISH_IT_AWAY_ID:
		_wish_set_text_effect_value(result, "WISH_IT_AWAY_EFFECT", 2)
	elif result.my_id == WISH_YOU_WERE_HERE_ID:
		_wish_set_text_effect_value(result, "WISH_YOU_WERE_HERE_EFFECT", 2)
	elif result.my_id == WISH_FOR_TREASURE_ID:
		_wish_set_text_effect_value(result, "WISH_FOR_TREASURE_EFFECT", 2)
	elif result.my_id == WISH_FOR_QUALITY_ID:
		_wish_set_stat_effect_value(result, "stat_harvesting", 120)
	elif result.my_id == WISH_FOR_FORTUNE_ID:
		_wish_set_stat_effect_value(result, "stat_luck", 40)
	elif result.my_id == WISH_FOR_KNOWLEDGE_ID:
		_wish_set_stat_effect_value(result, "xp_gain", 40)
		_wish_set_stat_effect_value(result, "number_of_enemies", 2)
	return result


func get_player_shop_items(wave: int, player_index: int, args: ItemServiceGetShopItemsArgs) -> Array:
	var lamp = wish_get_lamp_data()
	if lamp == null:
		return .get_player_shop_items(wave, player_index, args)

	var all_items_pool = _tiers_data[lamp.tier][TierData.ALL_ITEMS]
	var item_pool = _tiers_data[lamp.tier][TierData.ITEMS]
	var was_in_all_items_pool = all_items_pool.has(lamp)
	var was_in_item_pool = item_pool.has(lamp)
	var character = RunData.get_player_character(player_index)
	var is_djinn = character != null and character.my_id == DJINN_ID
	var is_profile_unlocked = ProgressData.items_unlocked.has(lamp.my_id_hash)
	var may_roll_lamp = (is_djinn or is_profile_unlocked) and not RunData.wish_has_bought_lamp_this_shop(player_index)
	_wish_remove_stale_lamp_ban(player_index, lamp)

	_wish_set_lamp_in_pool(all_items_pool, lamp, may_roll_lamp)
	_wish_set_lamp_in_pool(item_pool, lamp, may_roll_lamp)
	var result = .get_player_shop_items(wave, player_index, args)
	_wish_set_lamp_in_pool(all_items_pool, lamp, was_in_all_items_pool)
	_wish_set_lamp_in_pool(item_pool, lamp, was_in_item_pool)
	return result


func get_consumable_to_drop(unit: Unit, item_chance: float) -> ConsumableData:
	if RunData.crooked_consume_hunter_crate_if_needed(unit):
		return get_consumable_for_tier(Tier.UNCOMMON)
	if RunData.wish_consume_guaranteed_crate_if_needed(unit):
		return get_consumable_for_tier(Tier.UNCOMMON)

	var result = .get_consumable_to_drop(unit, item_chance)
	if result == null:
		return null

	if (
		RunData.crooked_has_active_calamity(RunData.CALAMITY_FAMINE)
		and result.my_id == FRUIT_ID
		and Utils.get_chance_success(0.5)
	):
		var poisoned_fruit = _wish_get_poisoned_fruit_data()
		if poisoned_fruit != null:
			return poisoned_fruit
	return result


func _wish_get_poisoned_fruit_data():
	if wish_poisoned_fruit_data == null:
		wish_poisoned_fruit_data = load(POISONED_FRUIT_PATH)
	return wish_poisoned_fruit_data


func _wish_remove_stale_lamp_ban(player_index: int, lamp: ItemData) -> void:
	# Older development builds briefly allowed Lamp to consume a ban token.
	# Treat either serialized ID representation as invalid so the unbannable
	# rule also repairs an in-progress run made with one of those builds.
	var banned_items = RunData.players_data[player_index].banned_items
	for ban_index in range(banned_items.size() - 1, -1, -1):
		var banned_value = banned_items[ban_index]
		if (banned_value is String and banned_value == lamp.my_id) or (not banned_value is String and int(banned_value) == lamp.my_id_hash):
			banned_items.remove(ban_index)


func _wish_set_lamp_in_pool(pool: Array, lamp: ItemData, should_be_present: bool) -> void:
	if should_be_present:
		if not pool.has(lamp):
			pool.push_back(lamp)
	else:
		while pool.has(lamp):
			pool.erase(lamp)


func wish_get_lamp_discount(item: ItemParentData) -> int:
	var boosted = BASE_CURSED_DISCOUNT * (1.0 + max(0.0, item.curse_factor))
	return min(MAX_CURSED_DISCOUNT, round(boosted)) as int


func wish_get_lamp_data():
	return wish_lamp_data if wish_lamp_data != null else _wish_find_by_id(items, LAMP_ID)


func wish_get_resource_data():
	return wish_resource_data if wish_resource_data != null else _wish_find_by_id(items, WISH_RESOURCE_ID)


func wish_get_paw_data():
	return wish_paw_data if wish_paw_data != null else _wish_find_by_id(items, PAW_ID)


func wish_update_paw_icon(charges: int) -> void:
	var paw = wish_get_paw_data()
	if paw == null or wish_paw_icons.empty():
		return
	paw.icon = wish_get_paw_icon(charges)


func wish_get_paw_icon(charges: int):
	if wish_paw_icons.empty():
		return null
	return wish_paw_icons[clamp(charges, 0, 3) as int]


func wish_get_placeholder_data():
	return wish_placeholder_data if wish_placeholder_data != null else _wish_find_by_id(items, PLACEHOLDER_ID)


func wish_get_active_lamp_icon():
	return wish_lamp_active_icon


func wish_get_used_lamp_icon():
	return wish_lamp_used_icon


func _wish_create_item(item_id: String, name_key: String, icon, tier: int, value: int, effects: Array) -> ItemData:
	var item = ItemData.new()
	item.my_id = item_id
	item.unlocked_by_default = true
	item.can_be_looted = true
	item.icon = icon
	item.name = name_key
	item.tier = tier
	item.value = value
	item.effects = effects
	item.tracking_text = ""
	item.is_lockable = true
	item.max_nb = -1
	item.item_appearances = []
	item.tags = []
	item._generate_hashes()
	items.push_back(item)
	return item


func _wish_set_text_effect_value(item: ItemParentData, text_key: String, value: int) -> void:
	for effect in item.effects:
		if effect.text_key == text_key:
			effect.value = value
			return


func _wish_set_stat_effect_value(item: ItemParentData, stat_key: String, value: int) -> void:
	for effect in item.effects:
		if effect.key == stat_key:
			effect.value = value
			return


func _wish_text_effect(text_key: String, value: int) -> Effect:
	var effect = Effect.new()
	effect.key = ""
	effect.text_key = text_key
	effect.value = value
	effect.effect_sign = Effect.Sign.NEUTRAL
	return effect


func _wish_stat_effect(stat_key: String, value: int) -> Effect:
	var effect = Effect.new()
	effect.key = stat_key
	effect.text_key = ""
	effect.value = value
	effect.effect_sign = Effect.Sign.NEUTRAL
	return effect


func _wish_labeled_stat_effect(stat_key: String, text_key: String, value: int, effect_sign: int) -> Effect:
	var effect = _wish_stat_effect(stat_key, value)
	effect.text_key = text_key
	effect.effect_sign = effect_sign
	return effect


func _wish_stat_gain_effect(stat_key: String, value: int) -> Effect:
	var effect_script = load("res://effects/items/stat_gains_modification_effect.gd")
	var effect = effect_script.new()
	effect.key = "effect_increase_stat_gains"
	effect.text_key = ""
	effect.value = value
	effect.effect_sign = Effect.Sign.NEUTRAL
	effect.stat_displayed = stat_key
	effect.stats_modified = [stat_key]
	return effect


func _wish_stat_on_level_up_effect(stat_key: String, value: int) -> Effect:
	var effect = Effect.new()
	effect.key = stat_key
	effect.text_key = "EFFECT_STAT_ON_LEVEL_UP"
	effect.value = value
	effect.custom_key = "stats_on_level_up"
	effect.storage_method = Effect.StorageMethod.KEY_VALUE
	effect.effect_sign = Effect.Sign.FROM_VALUE
	effect.custom_args = []
	effect._generate_hashes()
	return effect


func _wish_starting_weapon_effect(weapon_id: String) -> Effect:
	# This is the same native effect used by characters such as Engineer. The
	# weapon selected in the loadout screen is added first, then RunData applies
	# this effect as an additional starting weapon.
	var effect = Effect.new()
	effect.key = weapon_id
	effect.text_key = "effect_starting_item"
	effect.value = 1
	effect.custom_key = "starting_weapon"
	effect.storage_method = Effect.StorageMethod.KEY_VALUE
	effect.effect_sign = Effect.Sign.NEUTRAL
	effect.custom_args = []
	effect._generate_hashes()
	return effect


func _wish_starting_item_effect(item_id: String, count: int) -> Effect:
	var effect = Effect.new()
	effect.key = item_id
	effect.text_key = "effect_starting_item"
	effect.value = count
	effect.custom_key = "starting_item"
	effect.storage_method = Effect.StorageMethod.KEY_VALUE
	effect.effect_sign = Effect.Sign.NEUTRAL
	effect.custom_args = []
	effect._generate_hashes()
	return effect


func _wish_get_djinn_starting_weapons() -> Array:
	return _wish_get_starting_weapons(DJINN_STARTING_WEAPON_IDS)


func _wish_get_starting_weapons(weapon_ids: Array) -> Array:
	var result = []
	for weapon_id in weapon_ids:
		var weapon = _wish_find_by_id(weapons, weapon_id)
		if weapon != null:
			result.push_back(weapon)
	return result


func _wish_load_png(path: String) -> ImageTexture:
	var image = Image.new()
	var error = image.load(path)
	if error != OK:
		push_error("Wish could not load image: " + path + " (" + str(error) + ")")
		return ImageTexture.new()
	var texture = ImageTexture.new()
	texture.create_from_image(image, Texture.FLAG_FILTER)
	texture.take_over_path(path)
	return texture


func _wish_find_by_id(resources: Array, id: String):
	for resource in resources:
		if resource != null and resource.my_id == id:
			return resource
	return null
