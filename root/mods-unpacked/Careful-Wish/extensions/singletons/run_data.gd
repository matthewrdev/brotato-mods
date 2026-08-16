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


func reset(restart: bool = false) -> void:
	.reset(restart)
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
	if item != null and item.my_id == LAMP_ID:
		wish_grant_resources(1, player_index)
		if item.is_cursed:
			wish_queue_discount(ItemService.wish_get_lamp_discount(item), player_index)
	elif item != null and item.my_id == PAW_ID:
		crooked_grant_charges(PAW_MAX_CHARGES, player_index)


func on_wave_start(timer: WaveTimer) -> void:
	_crooked_activate_for_current_wave()
	.on_wave_start(timer)


func on_wave_end() -> void:
	.on_wave_end()
	_crooked_finish_active_wave()


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
	crooked_state.queued_calamities.push_back(selected)
	crooked_state.calamity_target_wave = current_wave + 1
	return selected


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
	if crooked_state.active_calamities.empty() and not crooked_state.queued_calamities.empty():
		crooked_state.active_calamities = crooked_state.queued_calamities.duplicate()
		crooked_state.queued_calamities.clear()
		crooked_state.active_wave = current_wave
		crooked_state.calamity_target_wave = current_wave
	elif not crooked_state.active_calamities.empty() and int(crooked_state.active_wave) != current_wave:
		_crooked_finish_active_wave()

	if crooked_state.active_calamities.empty() or bool(crooked_state.runtime_applied):
		return
	_crooked_apply_runtime_effects()


func _crooked_apply_runtime_effects() -> void:
	crooked_state.runtime_applied = true
	crooked_state.runtime_effect_restores = {}
	crooked_state.original_constant_projectile = constant_projectile

	var needs_night = crooked_has_active_calamity(CALAMITY_NIGHT)
	var needs_frenzy = crooked_has_active_calamity(CALAMITY_FRENZY)
	if needs_night or needs_frenzy:
		for player_index in get_player_count():
			var effects = get_player_effects(player_index)
			crooked_state.runtime_effect_restores[str(player_index)] = {
				"fog": effects[Keys.fog_of_war_event_hash],
				"bullet": effects[Keys.bullet_hell_event_hash],
				"enemy_speed": effects[Keys.enemy_speed_hash]
			}
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
		if crooked_state.hunter_elite_ids.empty():
			crooked_state.hunter_elite_ids.push_back(ItemService.get_random_elite_id_hash_from_zone(ZoneService.current_zone.my_id))
		crooked_state.hunter_crates_remaining = crooked_state.hunter_elite_ids.size()
		_crooked_queue_hunter_elites()


func _crooked_queue_hunter_elites() -> void:
	if get_player_count() <= 0:
		return
	var effects = get_player_effects(0)
	for elite_id in crooked_state.hunter_elite_ids:
		var already_queued = false
		for effect in effects[Keys.extra_enemies_next_wave_hash]:
			if effect.size() >= 3 and effect[0] == HUNTER_GROUP_PATH and int(effect[2]) == int(elite_id):
				already_queued = true
				break
		if not already_queued:
			effects[Keys.extra_enemies_next_wave_hash].push_back([HUNTER_GROUP_PATH, 1, int(elite_id)])


func _crooked_finish_active_wave() -> void:
	if crooked_state.empty() or crooked_state.active_calamities.empty():
		return

	for player_index in get_player_count():
		var restore = crooked_state.runtime_effect_restores.get(str(player_index), {})
		if restore is Dictionary and not restore.empty():
			var effects = get_player_effects(player_index)
			effects[Keys.fog_of_war_event_hash] = restore.get("fog", effects[Keys.fog_of_war_event_hash])
			effects[Keys.bullet_hell_event_hash] = restore.get("bullet", effects[Keys.bullet_hell_event_hash])
			effects[Keys.enemy_speed_hash] = restore.get("enemy_speed", effects[Keys.enemy_speed_hash])

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
	crooked_state = _crooked_new_state()
	crooked_state.queued_calamities = queued_for_later


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
