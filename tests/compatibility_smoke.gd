extends SceneTree

var failures = 0
var items
var run
var progress
var debug

func _init():
	if not OS.get_user_data_dir().get_file().begins_with("Brotato-Wish-smoke-"):
		printerr("Refusing to test against a normal save profile")
		quit(2)
		return
	call_deferred("_test")

func check(ok: bool, label: String):
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func find_id(pool: Array, id: String):
	for item in pool:
		if item.my_id == id:
			return item
	return null

func _test():
	items = root.get_node("ItemService")
	run = root.get_node("RunData")
	progress = root.get_node("ProgressData")
	debug = root.get_node("DebugService")
	debug.disable_saving = true
	debug.invulnerable = true
	debug.custom_wave_duration = 90
	check(items.has_method("wish_get_lamp_data"), "Wish extension loaded")
	if not items.has_method("wish_get_lamp_data"):
		quit(1)
		return
	var count_items = items.get_items().size()
	var count_characters = items.get_characters().size()
	items._wish_install_content()
	items.invalidate_items_cache()
	items.invalidate_characters_cache()
	items.invalidate_weapons_cache()
	check(items.get_items().size() == count_items, "Registration is idempotent and survives item cache rebuild")
	check(items.get_characters().size() == count_characters, "Characters survive cache rebuild without duplicates")
	items.init_unlocked_pool()
	for item_id in ["item_wish_for_company", "item_wish_it_away", "item_wish_you_were_here", "item_wish_for_treasure", "item_wish_for_quality", "item_wish_for_fortune", "item_wish_for_knowledge"]:
		var item = find_id(items.get_items(), item_id)
		check(item != null and items._tiers_data[item.tier][items.TierData.ITEMS].has(item), "Native shop pool contains " + item_id)
	for character_id in ["character_djinn", "character_shaman"]:
		var character = find_id(items.get_characters(), character_id)
		check(character != null and character.starting_weapons.size() == 8, character_id + " has eight starting weapons")
		run.reset()
		run.add_character(character, 0)
		run.add_weapon(character.starting_weapons[0].duplicate(), 0, true)
		run.add_starting_items_and_weapons()
		run.players_data[0].gold = 1000
		if character_id == "character_djinn":
			check(run.wish_get_resource_count(0) == 3, "Djinn starts with three Wishes")
		else:
			check(run.crooked_get_charges(0) == 3, "Shaman starts with three Paw charges")
			check(run.get_player_weapons(0).size() == 2, "Shaman starts with the extra Wand")
		var growth_key = root.get_node("Keys").generate_hash("harvesting_growth")
		var growth_before = run.get_player_effect(growth_key, 0)
		var growth = find_id(items.get_items(), "item_wish_for_treasure").duplicate()
		run.add_item(growth, 0)
		check(is_equal_approx(float(run.get_player_effect(growth_key, 0)), float(growth_before) + 0.3), "Growth applies fractional Harvesting growth")
		run.remove_item(growth, 0)
		check(is_equal_approx(float(run.get_player_effect(growth_key, 0)), float(growth_before)), "Removing Growth restores Harvesting growth")
		run.add_item(growth, 0)
		var corruption = find_id(items.get_items(), "item_wish_for_fortune").duplicate()
		run.add_item(corruption, 0)
		check(run.wish_corruption_result.get(0, []).size() == 1, "Corruption curses one inventory entry through the 1.2 DLC API")
		var growth_saved = run.get_player_effect(growth_key, 0)
		change_scene("res://ui/menus/shop/shop.tscn")
		yield(create_timer(0.4), "timeout")
		var shop = current_scene
		var choice = find_id(items.get_items(), "item_wish_for_knowledge")
		check(shop._wish_is_item_eligible(choice, 0, true, character_id == "character_shaman"), character_id + " can select a Wish item")
		if character_id == "character_djinn":
			shop._wish_picker_popups[0].set_meta("wish_source", "wish")
			shop._on_wish_choice_pressed(choice.my_id, 0)
			shop._on_wish_confirm_pressed(0)
			check(run.wish_get_resource_count(0) == 2, "Wish confirmation spends exactly one resource")
		else:
			shop._wish_picker_popups[0].set_meta("wish_source", "crooked")
			shop._on_wish_choice_pressed(choice.my_id, 0)
			shop._on_crooked_confirm_pressed(0)
			check(run.crooked_get_charges(0) == 2, "Crooked Wish spends exactly one Paw charge")
			check(run.crooked_get_queued_calamities().size() == 1, "Crooked Wish queues its Calamity")
		check(run.wish_get_pending_item_ids(0).has(choice.my_id), character_id + " queues the selected item")
		# Exercise the real save format, including Wish metadata and custom resources.
		debug.disable_saving = false
		progress.save_run_state(shop._shop_items, shop._reroll_count, shop._paid_reroll_count, shop._initial_free_rerolls, shop._free_rerolls, shop._item_steals)
		progress.load_game_file()
		run.resume_from_state(progress.saved_run_state)
		debug.disable_saving = true
		check(is_equal_approx(float(run.get_player_effect(growth_key, 0)), float(growth_saved)), "Growth survives disk save/resume")
		check(run.wish_get_pending_item_ids(0).has(choice.my_id), character_id + " queue survives disk save/resume")
		shop._on_RerollButton_pressed(0)
		var delivered = false
		for entry in shop._shop_items[0]:
			if entry[0].my_id == choice.my_id:
				delivered = true
		check(delivered and run.wish_get_pending_count(0) == 0, character_id + " delivers Wish into a normal reroll slot")
		# Force all wave effects together to cover their integration with 1.2.
		run.crooked_state = run._crooked_new_state()
		for calamity in run.CALAMITY_IDS:
			run.crooked_queue_calamity(calamity)
		run.current_wave = 5
		change_scene("res://main.tscn")
		yield(create_timer(5.0), "timeout")
		var spawner = current_scene.get_node("EntitySpawner")
		check(spawner.enemies.size() > 0, character_id + " wave spawns enemies (" + str(spawner.enemies.size()) + ")")
		check(run.crooked_get_active_calamities().size() == 5, "All five Calamities activate")
		check(spawner.bosses.size() > 0, "Hunter Calamity spawns an Elite")
		run.on_wave_end()
		check(run.crooked_get_active_calamities().empty(), "Calamities clear at wave end")
		current_scene.queue_free()
		current_scene = null
		yield(create_timer(0.1), "timeout")
	print("WISH_SMOKE_FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
