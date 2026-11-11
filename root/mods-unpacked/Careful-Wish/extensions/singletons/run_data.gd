extends "res://singletons/run_data.gd"

signal wish_shop_capacity_changed(player_index)

const WISH_AVAILABLE = 0
const WISH_QUEUED_CURRENT_SHOP = 1
const WISH_READY_NEXT_SHOP = 2
const WISH_DELIVERY_ACTIVE = 3
const WISH_DELIVERY_RESOLVED = 4

const DJINN_ID = "character_djinn"
const SHAMAN_ID = "character_shaman"
const LAMP_ID = "item_magic_lamp"
const PAW_ID = "item_monkeys_paw"
const COMPANY_WISH_ID = "item_wish_for_company"
const WISH_IT_AWAY_ID = "item_wish_it_away"
const WISH_YOU_WERE_HERE_ID = "item_wish_you_were_here"
const WISH_FOR_QUALITY_ID = "item_wish_for_quality"
const WISH_FOR_CORRUPTION_ID = "item_wish_for_fortune" # Keep saved item IDs compatible.
const WISH_FOR_KNOWLEDGE_ID = "item_wish_for_knowledge"
const WISH_RESOURCE_ID = "item_wish_resource"
const WISH_STATE_KEY = "matthew_wish"
const CROOKED_STATE_KEY = "matthew_crooked_wish"
const BASE_WISH_COST = 25
const WISH_COST_PER_WAVE = 4
const WISH_COST_PER_USE = 3
const WISH_LAYOUT_VERSION = 3
const WISH_RESOURCE_VERSION = 1
const DJINN_STARTING_WISHES = 3
const PAW_MAX_CHARGES = 3
const NIGHT_ENEMY_SPEED_BONUS = 10
const COMPANY_WISH_XP_BONUS = 10
const WISH_IT_AWAY_ENEMY_HEALTH_BONUS = 10
const WISH_FOR_QUALITY_ENEMY_HEALTH_BONUS = 15

const CALAMITY_HUNTER = "hunter"
const CALAMITY_HORDE = "horde"
const CALAMITY_NIGHT = "night"
const CALAMITY_FRENZY = "frenzy"
const CALAMITY_FAMINE = "famine"
const CALAMITY_IDS = [
	CALAMITY_HUNTER,
	CALAMITY_HORDE,
	CALAMITY_NIGHT,
	CALAMITY_FRENZY,
	CALAMITY_FAMINE
]
const HUNTER_GROUP_PATH = "res://zones/common/elite/group_elite.tres"

var wish_players = []
var crooked_state = {}
var wish_cursing_inventory = false
var wish_corruption_result = {}
var wish_xp_gain_hash = Keys.generate_hash("xp_gain")
var wish_enemy_health_hash = Keys.generate_hash("danger_enemy_health")
var wish_enemy_damage_hash = Keys.generate_hash("danger_enemy_damage")


func reset(restart: bool = false) -> void:
	.reset(restart)
	wish_cursing_inventory = false
	wish_corruption_result.clear()
	wish_players.clear()
	crooked_state = _crooked_new_state()
	_wish_ensure_players()
	_crooked_reconcile_paw_charges()
	_crooked_refresh_paw_icon()


func get_state() -> Dictionary:
	var state = .get_state()
	_wish_ensure_players()
	state[WISH_STATE_KEY] = wish_players.duplicate(true)
	state[CROOKED_STATE_KEY] = crooked_state.duplicate(true)
	return state


func resume_from_state(state: Dictionary) -> void:
	.resume_from_state(state)
	wish_cursing_inventory = false
	wish_corruption_result.clear()
	wish_players.clear()
	if state.has(WISH_STATE_KEY) and state[WISH_STATE_KEY] is Array:
		for saved_player in state[WISH_STATE_KEY]:
			wish_players.push_back(_wish_sanitize_player(saved_player))
	_wish_ensure_players()
	crooked_state = _crooked_sanitize_state(state.get(CROOKED_STATE_KEY, {}))
	_wish_migrate_resources()
	_crooked_reconcile_paw_charges()
	_crooked_refresh_paw_icon()


func add_item(item: ItemData, player_index: int, is_selection: bool = false) -> void:
	.add_item(item, player_index, is_selection)
	if wish_cursing_inventory:
		return
	if item != null and item.my_id == LAMP_ID:
		wish_grant_resources(1, player_index)
		if item.is_cursed:
			wish_queue_discount(ItemService.wish_get_lamp_discount(item), player_index)
	elif item != null and item.my_id == PAW_ID:
		crooked_grant_charges(PAW_MAX_CHARGES, player_index)
	elif item != null and item.my_id == COMPANY_WISH_ID:
		crooked_queue_calamity(CALAMITY_HORDE)
		if item.is_cursed:
			wish_queue_company_xp_bonus(player_index)
	elif item != null and item.my_id == WISH_IT_AWAY_ID:
		wish_grant_bans(2 if item.is_cursed else 1, player_index)
		wish_queue_enemy_health_bonus(WISH_IT_AWAY_ENEMY_HEALTH_BONUS)
	elif item != null and item.my_id == WISH_YOU_WERE_HERE_ID:
		crooked_queue_calamity(CALAMITY_HUNTER, true)
		if item.is_cursed:
			wish_queue_guaranteed_crates(1)
	elif item != null and item.my_id == WISH_FOR_QUALITY_ID:
		wish_queue_enemy_health_bonus(WISH_FOR_QUALITY_ENEMY_HEALTH_BONUS)
	elif item != null and item.my_id == WISH_FOR_CORRUPTION_ID:
		wish_corruption_result[player_index] = _wish_curse_inventory(player_index, 2 if item.is_cursed else 1)


func _wish_curse_inventory(player_index: int, count: int) -> Array:
	var cursed_names = []
	var dlc = ItemService.get_dlc_data_by_id("abyssal_terrors")
	if dlc == null:
		ModLoaderLog.warning("Wish for Corruption could not find Abyssal Terrors", "Careful-Wish")
		return cursed_names
	for _curse_index in count:
		var candidates = []
		for owned_item in get_player_items(player_index):
			if owned_item == null or owned_item.is_cursed:
				continue
			if owned_item.my_id.begins_with("character_"):
				continue
			if owned_item.my_id in [WISH_FOR_CORRUPTION_ID, WISH_RESOURCE_ID, "item_wish_empty_slot"]:
				continue
			candidates.push_back(owned_item)
		for weapon in get_player_weapons(player_index):
			if weapon != null and not weapon.is_cursed:
				candidates.push_back(weapon)
		if candidates.empty():
			return cursed_names

		candidates.shuffle()
		var original = null
		var cursed = null
		for candidate in candidates:
			var attempt = dlc.curse_item(candidate, player_index)
			if attempt != null and attempt.is_cursed:
				original = candidate
				cursed = attempt
				break
		if cursed == null:
			ModLoaderLog.warning("Wish for Corruption found no item or weapon the DLC could curse", "Careful-Wish")
			return cursed_names
		wish_cursing_inventory = true
		if original is WeaponData:
			remove_weapon(original, player_index)
			add_weapon(cursed, player_index)
		else:
			remove_item(original, player_index)
			add_item(cursed, player_index)
		wish_cursing_inventory = false
		cursed_names.push_back(cursed.get_name_text())
		ModLoaderLog.info("Wish for Corruption cursed " + cursed.my_id, "Careful-Wish")
	return cursed_names


func on_wave_start(timer: WaveTimer) -> void:
	_crooked_activate_for_current_wave()
	_wish_consume_wave_trigger_items()
	.on_wave_start(timer)


func on_wave_end() -> void:
	.on_wave_end()
	_crooked_finish_active_wave()


func _wish_consume_wave_trigger_items() -> void:
	var trigger_ids = [
		COMPANY_WISH_ID,
		WISH_IT_AWAY_ID,
		WISH_YOU_WERE_HERE_ID
	]
	for player_index in get_player_count():
		for item_id in trigger_ids:
			var item_hash = Keys.generate_hash(item_id)
			var trigger_item = get_player_item(item_hash, player_index)
			while trigger_item != null:
				remove_item(trigger_item, player_index, true)
				trigger_item = get_player_item(item_hash, player_index)


func wish_has_access(player_index: int) -> bool:
	if player_index < 0 or player_index >= get_player_count():
		return false
	var character = get_player_character(player_index)
	if character != null and character.my_id == DJINN_ID:
		return true
	return get_nb_item(Keys.generate_hash(LAMP_ID), player_index) > 0 or wish_get_resource_count(player_index) > 0


func wish_has_bought_lamp_this_shop(player_index: int) -> bool:
	return bool(wish_get_player_state(player_index).lamp_bought_this_shop)


func wish_mark_lamp_bought_this_shop(player_index: int) -> void:
	wish_get_player_state(player_index).lamp_bought_this_shop = true


func wish_get_player_state(player_index: int) -> Dictionary:
	_wish_ensure_players()
	return wish_players[player_index]


func wish_get_phase(player_index: int) -> int:
	return int(wish_get_player_state(player_index).phase)


func wish_get_cost(player_index: int) -> int:
	var wave_increase = max(0, current_wave - 1) * WISH_COST_PER_WAVE
	var use_increase = max(0, int(wish_get_player_state(player_index).wish_count)) * WISH_COST_PER_USE
	return BASE_WISH_COST + wave_increase + use_increase


func wish_get_resource_count(player_index: int) -> int:
	return get_nb_item(Keys.generate_hash(WISH_RESOURCE_ID), player_index)


func wish_grant_resources(count: int, player_index: int) -> void:
	var resource = ItemService.wish_get_resource_data()
	if resource == null:
		return
	for _resource_index in max(0, count):
		.add_item(resource, player_index)


func wish_consume_resource(player_index: int) -> bool:
	var resource = get_player_item(Keys.generate_hash(WISH_RESOURCE_ID), player_index)
	if resource == null:
		return false
	remove_item(resource, player_index, true)
	return true


func wish_has_next_shop() -> bool:
	return is_endless_run or current_wave < nb_of_waves - 1


func wish_get_pending_item_ids(player_index: int) -> Array:
	return wish_get_player_state(player_index).pending_item_ids.duplicate()


func wish_get_pending_count(player_index: int) -> int:
	return wish_get_player_state(player_index).pending_item_ids.size()


func wish_get_available_delivery_slots(player_index: int) -> int:
	var locked_count = get_player_locked_shop_items(player_index).size()
	return max(0, ItemService.NB_SHOP_ITEMS - locked_count - wish_get_pending_count(player_index)) as int


func wish_can_queue_item(player_index: int) -> bool:
	var phase = wish_get_phase(player_index)
	return (phase == WISH_AVAILABLE or phase == WISH_QUEUED_CURRENT_SHOP) and wish_get_available_delivery_slots(player_index) > 0


func wish_can_lock_shop_item(player_index: int) -> bool:
	return get_player_locked_shop_items(player_index).size() + wish_get_pending_count(player_index) < ItemService.NB_SHOP_ITEMS


func wish_queue_item(item_id: String, player_index: int) -> bool:
	if not wish_can_queue_item(player_index):
		return false
	var state = wish_get_player_state(player_index)
	state.phase = WISH_QUEUED_CURRENT_SHOP
	state.pending_item_ids.push_back(item_id)
	state.pending_item_id = str(state.pending_item_ids[0])
	state.wish_count = int(state.wish_count) + 1
	state.delivery_result = ""
	emit_signal("wish_shop_capacity_changed", player_index)
	return true


func wish_queue_crooked_item(item_id: String, player_index: int) -> bool:
	if not wish_can_queue_item(player_index):
		return false
	var state = wish_get_player_state(player_index)
	state.phase = WISH_QUEUED_CURRENT_SHOP
	state.pending_item_ids.push_back(item_id)
	state.pending_item_id = str(state.pending_item_ids[0])
	state.delivery_result = ""
	emit_signal("wish_shop_capacity_changed", player_index)
	return true


func crooked_has_access(player_index: int) -> bool:
	if player_index < 0 or player_index >= get_player_count():
		return false
	var character = get_player_character(player_index)
	return (character != null and character.my_id == SHAMAN_ID) or get_nb_item(Keys.generate_hash(PAW_ID), player_index) > 0


func crooked_get_charges(player_index: int) -> int:
	_crooked_reconcile_player_paw_charges(player_index)
	return int(wish_get_player_state(player_index).paw_charges)


func crooked_grant_charges(count: int, player_index: int) -> void:
	var state = wish_get_player_state(player_index)
	state.paw_charges = clamp(int(state.paw_charges) + max(0, count), 0, PAW_MAX_CHARGES) as int
	_crooked_update_player_paw_icon(player_index)


func crooked_consume_charge(player_index: int) -> bool:
	var state = wish_get_player_state(player_index)
	if int(state.paw_charges) <= 0:
		return false
	state.paw_charges = int(state.paw_charges) - 1
	state.paw_uses = int(state.paw_uses) + 1
	_crooked_update_player_paw_icon(player_index)
	return true


func _crooked_reconcile_paw_charges() -> void:
	for player_index in get_player_count():
		_crooked_reconcile_player_paw_charges(player_index)


func _crooked_reconcile_player_paw_charges(player_index: int) -> void:
	if player_index < 0 or player_index >= get_player_count():
		return
	if get_nb_item(Keys.generate_hash(PAW_ID), player_index) <= 0:
		return
	var state = wish_get_player_state(player_index)
	var expected_remaining = max(0, PAW_MAX_CHARGES - int(state.paw_uses)) as int
	if int(state.paw_charges) >= expected_remaining:
		return
	state.paw_charges = expected_remaining
	ModLoaderLog.info("Restored Monkey's Paw charges after run reset for player " + str(player_index + 1), "Careful-Wish")


func crooked_queue_random_calamity() -> String:
	var available = CALAMITY_IDS.duplicate()
	for calamity_id in crooked_state.queued_calamities:
		available.erase(calamity_id)
	if available.empty():
		available = CALAMITY_IDS.duplicate()
	var selected = str(Utils.get_rand_element(available))
	# Once every distinct Calamity is queued, Crooked Wishes may stack them as
	# they did before explicit Calamity scheduling was introduced.
	crooked_queue_calamity(selected, true)
	return selected


func crooked_queue_calamity(calamity_id: String, allow_duplicate: bool = false) -> bool:
	if not CALAMITY_IDS.has(calamity_id):
		return false
	if allow_duplicate or not crooked_state.queued_calamities.has(calamity_id):
		crooked_state.queued_calamities.push_back(calamity_id)
	crooked_state.calamity_target_wave = current_wave + 1
	return true


func wish_queue_company_xp_bonus(player_index: int) -> void:
	if player_index < 0 or player_index >= get_player_count():
		return
	if not crooked_state.queued_company_xp_players.has(player_index):
		crooked_state.queued_company_xp_players.push_back(player_index)


func wish_grant_bans(count: int, player_index: int) -> void:
	if player_index < 0 or player_index >= get_player_count():
		return
	players_data[player_index].uses_ban = true
	players_data[player_index].remaining_ban_token = int(players_data[player_index].remaining_ban_token) + max(0, count)


func wish_queue_enemy_health_bonus(amount: int) -> void:
	crooked_state.queued_enemy_health_bonus = int(crooked_state.queued_enemy_health_bonus) + max(0, amount)
	crooked_state.calamity_target_wave = current_wave + 1


func wish_queue_enemy_damage_bonus(amount: int) -> void:
	crooked_state.queued_enemy_damage_bonus = int(crooked_state.queued_enemy_damage_bonus) + max(0, amount)
	crooked_state.calamity_target_wave = current_wave + 1


func wish_queue_guaranteed_crates(count: int) -> void:
	crooked_state.queued_guaranteed_crates = int(crooked_state.queued_guaranteed_crates) + max(0, count)
	crooked_state.calamity_target_wave = current_wave + 1


func crooked_get_queued_calamities() -> Array:
	return crooked_state.queued_calamities.duplicate()


func crooked_get_active_calamities() -> Array:
	return crooked_state.active_calamities.duplicate()


func crooked_has_active_calamity(calamity_id: String) -> bool:
	return crooked_state.active_calamities.has(calamity_id)


func crooked_consume_hunter_crate_if_needed(unit: Unit) -> bool:
	if unit == null or not unit is Boss or not crooked_has_active_calamity(CALAMITY_HUNTER):
		return false
	if not crooked_state.hunter_elite_ids.has(int(unit.enemy_id_hash)):
		return false
	if int(crooked_state.hunter_crates_remaining) <= 0:
		return false
	crooked_state.hunter_crates_remaining = int(crooked_state.hunter_crates_remaining) - 1
	return true


func wish_consume_guaranteed_crate_if_needed(unit: Unit) -> bool:
	if unit == null or int(crooked_state.active_guaranteed_crates) <= 0:
		return false
	crooked_state.active_guaranteed_crates = int(crooked_state.active_guaranteed_crates) - 1
	return true


func wish_begin_delivery(player_index: int) -> bool:
	var state = wish_get_player_state(player_index)
	if int(state.phase) != WISH_READY_NEXT_SHOP:
		return false
	state.phase = WISH_DELIVERY_ACTIVE
	state.delivery_result = ""
	return true


func wish_resolve_delivery(player_index: int, result: String = "fulfilled") -> void:
	var state = wish_get_player_state(player_index)
	state.phase = WISH_DELIVERY_RESOLVED
	state.delivery_result = result


func wish_complete_shop_delivery(player_index: int) -> void:
	var state = wish_get_player_state(player_index)
	state.phase = WISH_AVAILABLE
	state.pending_item_ids.clear()
	state.pending_item_id = ""
	state.delivery_result = "fulfilled"
	emit_signal("wish_shop_capacity_changed", player_index)


func wish_leave_shop(player_index: int) -> void:
	var state = wish_get_player_state(player_index)
	state.lamp_bought_this_shop = false
	match int(state.phase):
		WISH_READY_NEXT_SHOP, WISH_DELIVERY_ACTIVE:
			state.phase = WISH_QUEUED_CURRENT_SHOP if not state.pending_item_ids.empty() else WISH_AVAILABLE
		WISH_DELIVERY_RESOLVED:
			state.phase = WISH_AVAILABLE
			state.pending_item_ids.clear()
			state.pending_item_id = ""
			state.delivery_result = ""


func wish_queue_discount(percent: int, player_index: int) -> void:
	var state = wish_get_player_state(player_index)
	state.discount_queue.push_back(clamp(percent, 1, 90) as int)


func wish_get_discount(player_index: int) -> int:
	var queue = wish_get_player_state(player_index).discount_queue
	return int(queue[0]) if queue.size() > 0 else 0


func wish_consume_discount(player_index: int) -> int:
	var queue = wish_get_player_state(player_index).discount_queue
	if queue.empty():
		return 0
	return int(queue.pop_front())


func wish_needs_external_layout_migration(player_index: int) -> bool:
	return int(wish_get_player_state(player_index).layout_version) < WISH_LAYOUT_VERSION


func wish_mark_external_layout_migrated(player_index: int) -> void:
	wish_get_player_state(player_index).layout_version = WISH_LAYOUT_VERSION


func _wish_ensure_players() -> void:
	while wish_players.size() < get_player_count():
		wish_players.push_back(_wish_new_player())
	if wish_players.size() > get_player_count():
		wish_players.resize(get_player_count())


func _wish_new_player() -> Dictionary:
	return {
		"phase": WISH_AVAILABLE,
		"wish_count": 0,
		"pending_item_ids": [],
		"pending_item_id": "",
		"lamp_bought_this_shop": false,
		"paw_charges": 0,
		"paw_uses": 0,
		"discount_queue": [],
		"delivery_result": "",
		"layout_version": WISH_LAYOUT_VERSION,
		"resource_version": WISH_RESOURCE_VERSION
	}


func _wish_sanitize_player(saved) -> Dictionary:
	var result = _wish_new_player()
	if not saved is Dictionary:
		return result
	result.phase = int(saved.get("phase", WISH_AVAILABLE))
	result.wish_count = int(saved.get("wish_count", 0))
	var saved_pending_items = saved.get("pending_item_ids", [])
	if saved_pending_items is Array:
		for saved_item_id in saved_pending_items:
			var item_id = str(saved_item_id)
			if not item_id.empty():
				result.pending_item_ids.push_back(item_id)
	if result.pending_item_ids.empty() and result.phase in [WISH_QUEUED_CURRENT_SHOP, WISH_READY_NEXT_SHOP, WISH_DELIVERY_ACTIVE]:
		var legacy_item_id = str(saved.get("pending_item_id", ""))
		if not legacy_item_id.empty():
			result.pending_item_ids.push_back(legacy_item_id)
	result.pending_item_id = str(result.pending_item_ids[0]) if not result.pending_item_ids.empty() else ""
	result.lamp_bought_this_shop = bool(saved.get("lamp_bought_this_shop", false))
	result.paw_charges = clamp(int(saved.get("paw_charges", 0)), 0, PAW_MAX_CHARGES) as int
	result.paw_uses = max(0, int(saved.get("paw_uses", 0)))
	if not result.pending_item_ids.empty():
		result.phase = WISH_QUEUED_CURRENT_SHOP
	else:
		result.phase = WISH_AVAILABLE
	result.delivery_result = str(saved.get("delivery_result", ""))
	result.layout_version = int(saved.get("layout_version", 1))
	result.resource_version = int(saved.get("resource_version", 0))
	var saved_queue = saved.get("discount_queue", [])
	if saved_queue is Array:
		for value in saved_queue:
			result.discount_queue.push_back(clamp(int(value), 1, 90))
	return result


func _wish_migrate_resources() -> void:
	for player_index in get_player_count():
		var state = wish_get_player_state(player_index)
		if int(state.resource_version) >= WISH_RESOURCE_VERSION:
			continue

		var entitlement = get_nb_item(Keys.generate_hash(LAMP_ID), player_index)
		var character = get_player_character(player_index)
		if character != null and character.my_id == DJINN_ID:
			entitlement += DJINN_STARTING_WISHES
		var target_remaining = max(0, entitlement - int(state.wish_count))
		var missing = max(0, target_remaining - wish_get_resource_count(player_index))
		wish_grant_resources(missing, player_index)
		state.resource_version = WISH_RESOURCE_VERSION


func _crooked_new_state() -> Dictionary:
	return {
		"queued_calamities": [],
		"calamity_target_wave": -1,
		"active_calamities": [],
		"queued_company_xp_players": [],
		"active_company_xp_players": [],
		"queued_enemy_health_bonus": 0,
		"active_enemy_health_bonus": 0,
		"queued_enemy_damage_bonus": 0,
		"active_enemy_damage_bonus": 0,
		"queued_guaranteed_crates": 0,
		"active_guaranteed_crates": 0,
		"active_wave": -1,
		"runtime_applied": false,
		"runtime_effect_restores": {},
		"original_constant_projectile": 1,
		"fog_event_added": false,
		"frenzy_event_added": false,
		"horde_event_added": false,
		"hunter_elite_ids": [],
		"hunter_crates_remaining": 0
	}


func _crooked_sanitize_state(saved) -> Dictionary:
	var result = _crooked_new_state()
	if not saved is Dictionary:
		return result
	for field_name in ["queued_calamities", "active_calamities"]:
		var saved_ids = saved.get(field_name, [])
		if saved_ids is Array:
			for calamity_id_value in saved_ids:
				var calamity_id = str(calamity_id_value)
				if CALAMITY_IDS.has(calamity_id):
					result[field_name].push_back(calamity_id)
	for field_name in ["queued_company_xp_players", "active_company_xp_players"]:
		var saved_players = saved.get(field_name, [])
		if saved_players is Array:
			for player_index_value in saved_players:
				var player_index = int(player_index_value)
				if player_index >= 0 and player_index < get_player_count() and not result[field_name].has(player_index):
					result[field_name].push_back(player_index)
	result.queued_enemy_health_bonus = max(0, int(saved.get("queued_enemy_health_bonus", 0)))
	result.active_enemy_health_bonus = max(0, int(saved.get("active_enemy_health_bonus", 0)))
	result.queued_enemy_damage_bonus = max(0, int(saved.get("queued_enemy_damage_bonus", 0)))
	result.active_enemy_damage_bonus = max(0, int(saved.get("active_enemy_damage_bonus", 0)))
	result.queued_guaranteed_crates = max(0, int(saved.get("queued_guaranteed_crates", 0)))
	result.active_guaranteed_crates = max(0, int(saved.get("active_guaranteed_crates", 0)))
	result.calamity_target_wave = int(saved.get("calamity_target_wave", -1))
	result.active_wave = int(saved.get("active_wave", -1))
	result.runtime_applied = bool(saved.get("runtime_applied", false))
	var saved_restores = saved.get("runtime_effect_restores", {})
	result.runtime_effect_restores = saved_restores.duplicate(true) if saved_restores is Dictionary else {}
	result.original_constant_projectile = int(saved.get("original_constant_projectile", 1))
	result.fog_event_added = bool(saved.get("fog_event_added", false))
	result.frenzy_event_added = bool(saved.get("frenzy_event_added", false))
	result.horde_event_added = bool(saved.get("horde_event_added", false))
	var saved_elite_ids = saved.get("hunter_elite_ids", [])
	if saved_elite_ids is Array:
		for elite_id in saved_elite_ids:
			result.hunter_elite_ids.push_back(int(elite_id))
	result.hunter_crates_remaining = max(0, int(saved.get("hunter_crates_remaining", 0)))
	return result


func _crooked_refresh_paw_icon() -> void:
	var charges = PAW_MAX_CHARGES
	for player_index in get_player_count():
		if crooked_has_access(player_index):
			charges = crooked_get_charges(player_index)
			_crooked_update_player_paw_icon(player_index)
	ItemService.wish_update_paw_icon(charges)


func _crooked_update_player_paw_icon(player_index: int) -> void:
	var charges = crooked_get_charges(player_index)
	var icon = ItemService.wish_get_paw_icon(charges)
	if icon == null:
		return
	ItemService.wish_update_paw_icon(charges)
	for item in get_player_items(player_index):
		if item != null and item.my_id == PAW_ID:
			item.icon = icon


func _crooked_activate_for_current_wave() -> void:
	if _crooked_has_active_wave_effects() and int(crooked_state.active_wave) != current_wave:
		_crooked_finish_active_wave()

	if not _crooked_has_active_wave_effects() and _crooked_has_queued_wave_effects():
		crooked_state.active_calamities = crooked_state.queued_calamities.duplicate()
		crooked_state.queued_calamities.clear()
		crooked_state.active_company_xp_players = crooked_state.queued_company_xp_players.duplicate()
		crooked_state.queued_company_xp_players.clear()
		crooked_state.active_enemy_health_bonus = int(crooked_state.queued_enemy_health_bonus)
		crooked_state.queued_enemy_health_bonus = 0
		crooked_state.active_enemy_damage_bonus = int(crooked_state.queued_enemy_damage_bonus)
		crooked_state.queued_enemy_damage_bonus = 0
		crooked_state.active_guaranteed_crates = int(crooked_state.queued_guaranteed_crates)
		crooked_state.queued_guaranteed_crates = 0
		crooked_state.active_wave = current_wave
		crooked_state.calamity_target_wave = current_wave

	if not _crooked_has_active_wave_effects() or bool(crooked_state.runtime_applied):
		return
	_crooked_apply_runtime_effects()


func _crooked_has_queued_wave_effects() -> bool:
	return (
		not crooked_state.queued_calamities.empty()
		or not crooked_state.queued_company_xp_players.empty()
		or int(crooked_state.queued_enemy_health_bonus) > 0
		or int(crooked_state.queued_enemy_damage_bonus) > 0
		or int(crooked_state.queued_guaranteed_crates) > 0
	)


func _crooked_has_active_wave_effects() -> bool:
	return (
		not crooked_state.active_calamities.empty()
		or not crooked_state.active_company_xp_players.empty()
		or int(crooked_state.active_enemy_health_bonus) > 0
		or int(crooked_state.active_enemy_damage_bonus) > 0
		or int(crooked_state.active_guaranteed_crates) > 0
	)


func _crooked_apply_runtime_effects() -> void:
	crooked_state.runtime_applied = true
	crooked_state.runtime_effect_restores = {}
	crooked_state.original_constant_projectile = constant_projectile

	var needs_night = crooked_has_active_calamity(CALAMITY_NIGHT)
	var needs_frenzy = crooked_has_active_calamity(CALAMITY_FRENZY)
	var has_company_xp_bonus = not crooked_state.active_company_xp_players.empty()
	var enemy_health_bonus = int(crooked_state.active_enemy_health_bonus)
	var enemy_damage_bonus = int(crooked_state.active_enemy_damage_bonus)
	if needs_night or needs_frenzy or has_company_xp_bonus or enemy_health_bonus > 0 or enemy_damage_bonus > 0:
		for player_index in get_player_count():
			var effects = get_player_effects(player_index)
			crooked_state.runtime_effect_restores[str(player_index)] = {
				"fog": effects[Keys.fog_of_war_event_hash],
				"bullet": effects[Keys.bullet_hell_event_hash],
				"enemy_speed": effects[Keys.enemy_speed_hash],
				"xp_gain": effects.get(wish_xp_gain_hash, 0),
				"enemy_health": effects.get(wish_enemy_health_hash, 0),
				"enemy_damage": effects.get(wish_enemy_damage_hash, 0)
			}
			if crooked_state.active_company_xp_players.has(player_index):
				effects[wish_xp_gain_hash] = int(effects.get(wish_xp_gain_hash, 0)) + COMPANY_WISH_XP_BONUS
			# Enemy Health and Damage are global effects, so stacked Wish prices are
			# applied once rather than once per co-op player.
			if player_index == 0:
				if enemy_health_bonus > 0:
					effects[wish_enemy_health_hash] = int(effects.get(wish_enemy_health_hash, 0)) + enemy_health_bonus
				if enemy_damage_bonus > 0:
					effects[wish_enemy_damage_hash] = int(effects.get(wish_enemy_damage_hash, 0)) + enemy_damage_bonus
			if needs_night:
				effects[Keys.fog_of_war_event_hash] = max(1, int(effects[Keys.fog_of_war_event_hash]))
				# Enemy speed is global, so apply the +10% calamity bonus once
				# rather than once per co-op player.
				if player_index == 0:
					effects[Keys.enemy_speed_hash] = int(effects[Keys.enemy_speed_hash]) + NIGHT_ENEMY_SPEED_BONUS
			if needs_frenzy:
				effects[Keys.bullet_hell_event_hash] = max(1, int(effects[Keys.bullet_hell_event_hash]))

	if needs_night and not events_fog_of_war.has(current_wave):
		events_fog_of_war.push_back(current_wave)
		crooked_state.fog_event_added = true
	if needs_frenzy:
		constant_projectile = 1
		if not events_bullet_hell.has(current_wave):
			events_bullet_hell.push_back(current_wave)
			crooked_state.frenzy_event_added = true

	if crooked_has_active_calamity(CALAMITY_HORDE):
		var has_horde = false
		for elite_spawn in elites_spawn:
			if int(elite_spawn[0]) == current_wave and int(elite_spawn[1]) == EliteType.HORDE:
				has_horde = true
				break
		if not has_horde:
			elites_spawn.push_front([current_wave, EliteType.HORDE, Keys.empty_hash])
			crooked_state.horde_event_added = true

	if crooked_has_active_calamity(CALAMITY_HUNTER):
		var hunter_count = crooked_state.active_calamities.count(CALAMITY_HUNTER)
		while crooked_state.hunter_elite_ids.size() < hunter_count:
			crooked_state.hunter_elite_ids.push_back(ItemService.get_random_elite_id_hash_from_zone(ZoneService.current_zone.my_id))
		crooked_state.hunter_crates_remaining = max(
			int(crooked_state.hunter_crates_remaining),
			crooked_state.hunter_elite_ids.size()
		)
		_crooked_queue_hunter_elites()


func _crooked_queue_hunter_elites() -> void:
	if get_player_count() <= 0:
		return
	var effects = get_player_effects(0)
	var queued_counts = {}
	for effect in effects[Keys.extra_enemies_next_wave_hash]:
		if effect.size() >= 3 and effect[0] == HUNTER_GROUP_PATH:
			var queued_key = str(int(effect[2]))
			queued_counts[queued_key] = int(queued_counts.get(queued_key, 0)) + 1
	var desired_counts = {}
	for elite_id in crooked_state.hunter_elite_ids:
		var elite_key = str(int(elite_id))
		desired_counts[elite_key] = int(desired_counts.get(elite_key, 0)) + 1
		if int(queued_counts.get(elite_key, 0)) < int(desired_counts[elite_key]):
			effects[Keys.extra_enemies_next_wave_hash].push_back([HUNTER_GROUP_PATH, 1, int(elite_id)])
			queued_counts[elite_key] = int(queued_counts.get(elite_key, 0)) + 1


func _crooked_finish_active_wave() -> void:
	if crooked_state.empty() or not _crooked_has_active_wave_effects():
		return

	for player_index in get_player_count():
		var restore = crooked_state.runtime_effect_restores.get(str(player_index), {})
		if restore is Dictionary and not restore.empty():
			var effects = get_player_effects(player_index)
			effects[Keys.fog_of_war_event_hash] = restore.get("fog", effects[Keys.fog_of_war_event_hash])
			effects[Keys.bullet_hell_event_hash] = restore.get("bullet", effects[Keys.bullet_hell_event_hash])
			effects[Keys.enemy_speed_hash] = restore.get("enemy_speed", effects[Keys.enemy_speed_hash])
			effects[wish_xp_gain_hash] = restore.get("xp_gain", effects.get(wish_xp_gain_hash, 0))
			effects[wish_enemy_health_hash] = restore.get("enemy_health", effects.get(wish_enemy_health_hash, 0))
			effects[wish_enemy_damage_hash] = restore.get("enemy_damage", effects.get(wish_enemy_damage_hash, 0))

	constant_projectile = int(crooked_state.original_constant_projectile)
	if bool(crooked_state.fog_event_added):
		events_fog_of_war.erase(int(crooked_state.active_wave))
	if bool(crooked_state.frenzy_event_added):
		events_bullet_hell.erase(int(crooked_state.active_wave))
	if bool(crooked_state.horde_event_added):
		for spawn_index in range(elites_spawn.size() - 1, -1, -1):
			var elite_spawn = elites_spawn[spawn_index]
			if int(elite_spawn[0]) == int(crooked_state.active_wave) and int(elite_spawn[1]) == EliteType.HORDE:
				elites_spawn.remove(spawn_index)
				break
	_crooked_remove_hunter_elites()

	var queued_for_later = crooked_state.queued_calamities.duplicate()
	var queued_company_xp_for_later = crooked_state.queued_company_xp_players.duplicate()
	var queued_enemy_health_for_later = int(crooked_state.queued_enemy_health_bonus)
	var queued_enemy_damage_for_later = int(crooked_state.queued_enemy_damage_bonus)
	var queued_crates_for_later = int(crooked_state.queued_guaranteed_crates)
	crooked_state = _crooked_new_state()
	crooked_state.queued_calamities = queued_for_later
	crooked_state.queued_company_xp_players = queued_company_xp_for_later
	crooked_state.queued_enemy_health_bonus = queued_enemy_health_for_later
	crooked_state.queued_enemy_damage_bonus = queued_enemy_damage_for_later
	crooked_state.queued_guaranteed_crates = queued_crates_for_later


func _crooked_remove_hunter_elites() -> void:
	if get_player_count() <= 0:
		return
	var effects = get_player_effects(0)
	for effect_index in range(effects[Keys.extra_enemies_next_wave_hash].size() - 1, -1, -1):
		var effect = effects[Keys.extra_enemies_next_wave_hash][effect_index]
		if effect.size() >= 3 and effect[0] == HUNTER_GROUP_PATH and crooked_state.hunter_elite_ids.has(int(effect[2])):
			effects[Keys.extra_enemies_next_wave_hash].remove(effect_index)
	var at_wave = effects[Keys.extra_enemies_at_wave_hash]
	var wave_key = str(crooked_state.active_wave)
	if at_wave.has(wave_key):
		for effect_index in range(at_wave[wave_key].size() - 1, -1, -1):
			var effect = at_wave[wave_key][effect_index]
			if effect.size() >= 3 and effect[0] == HUNTER_GROUP_PATH and crooked_state.hunter_elite_ids.has(int(effect[2])):
				at_wave[wave_key].remove(effect_index)
