extends "res://ui/menus/shop/base_shop.gd"

const LAMP_ID = "item_magic_lamp"
const CORRUPTION_ID = "item_wish_for_fortune" # Saved item ID retained from Wish for Fortune.
const DJINN_ID = "character_djinn"
const PLACEHOLDER_ID = "item_wish_empty_slot"
const WISH_CARD_FONT = preload("res://resources/fonts/actual/base/font_very_smallest_text.tres")

var _wish_action_buttons = [null, null, null, null]
var _crooked_action_buttons = [null, null, null, null]
var _wish_picker_popups = [null, null, null, null]
var _wish_picker_titles = [null, null, null, null]
var _wish_picker_lists = [null, null, null, null]
var _wish_picker_cost_labels = [null, null, null, null]
var _wish_picker_confirm_buttons = [null, null, null, null]
var _wish_picker_cancel_buttons = [null, null, null, null]
var _wish_picker_search_fields = [null, null, null, null]
var _wish_picker_return_focus = [null, null, null, null]
var _wish_reroll_left_neighbors = [null, null, null, null]


func _ready() -> void:
	if not RunData.is_connected("wish_shop_capacity_changed", self, "_on_wish_shop_capacity_changed"):
		RunData.connect("wish_shop_capacity_changed", self, "_on_wish_shop_capacity_changed")
	var migrated_legacy_shop = false
	for player_index in RunData.get_player_count():
		if _wish_migrate_legacy_shop(player_index):
			migrated_legacy_shop = true
		_wish_create_action_button(player_index)
		_crooked_create_action_button(player_index)
		_wish_create_picker(player_index)
		_wish_refresh_action(player_index)
		_wish_update_action_focus(player_index)
	if migrated_legacy_shop:
		_update_visual_locks()
		ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)


func fill_shop_items(player_locked_items: Array, player_index: int, just_entered_shop: bool = false) -> void:
	var delivery_ids = []
	var effective_locked_items = player_locked_items
	if not just_entered_shop and RunData.wish_get_phase(player_index) == RunData.WISH_QUEUED_CURRENT_SHOP:
		delivery_ids = RunData.wish_get_pending_item_ids(player_index)
		effective_locked_items = _wish_trim_locks_for_delivery(player_index, delivery_ids.size())

	.fill_shop_items(effective_locked_items, player_index, just_entered_shop)
	if not delivery_ids.empty():
		_wish_insert_deliveries_into_shop(delivery_ids, effective_locked_items.size(), player_index)


func _wish_trim_locks_for_delivery(player_index: int, delivery_count: int) -> Array:
	var max_locked = max(0, ItemService.NB_SHOP_ITEMS - min(delivery_count, ItemService.NB_SHOP_ITEMS))
	var saved_locks = RunData.locked_shop_items[player_index]
	while saved_locks.size() > max_locked:
		var removed_lock = saved_locks.pop_back()
		ModLoaderLog.warning("Released a legacy lock to guarantee wished shop slots: " + str(removed_lock[0].my_id), "Careful-Wish")
	return saved_locks.duplicate()


func _wish_insert_deliveries_into_shop(delivery_ids: Array, first_delivery_index: int, player_index: int) -> void:
	var delivery_index = first_delivery_index
	for item_id_value in delivery_ids:
		if delivery_index >= ItemService.NB_SHOP_ITEMS:
			break
		var item = _wish_find_item(str(item_id_value))
		if item == null:
			RunData.wish_grant_resources(1, player_index)
			ModLoaderLog.error("Refunded a Wish because its item no longer exists: " + str(item_id_value), "Careful-Wish")
			continue
		var delivered_item = ItemService.apply_item_effect_modifications(item, player_index)
		_shop_items[player_index][delivery_index] = [delivered_item, RunData.current_wave]
		delivery_index += 1
	RunData.wish_complete_shop_delivery(player_index)
	ModLoaderLog.info("Inserted " + str(delivery_index - first_delivery_index) + " wished item(s) into native shop slots for player " + str(player_index + 1), "Careful-Wish")


func _on_RerollButton_pressed(player_index: int) -> void:
	var reroll_count_before = _reroll_count[player_index]
	._on_RerollButton_pressed(player_index)
	if _reroll_count[player_index] > reroll_count_before:
		# Parent BaseShop normally dispatches its fill call through this extension.
		# Keep this fallback for ModLoader combinations that bind the parent call
		# statically, so a successful reroll can never leave a paid queue stranded.
		if RunData.wish_get_phase(player_index) == RunData.WISH_QUEUED_CURRENT_SHOP:
			var delivery_ids = RunData.wish_get_pending_item_ids(player_index)
			var effective_locks = _wish_trim_locks_for_delivery(player_index, delivery_ids.size())
			_wish_insert_deliveries_into_shop(delivery_ids, effective_locks.size(), player_index)
			_get_shop_items_container(player_index).set_shop_items(_shop_items[player_index])
		ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)
	_wish_refresh_action(player_index)


func on_shop_item_bought(shop_item: ShopItem, player_index: int) -> void:
	var has_wish_shop = RunData.wish_has_access(player_index)
	var bought_lamp = shop_item != null and shop_item.item_data != null and shop_item.item_data.my_id == LAMP_ID
	var bought_corruption = shop_item != null and shop_item.item_data != null and shop_item.item_data.my_id == CORRUPTION_ID
	if has_wish_shop:
		# BaseShop removes the first entry with the same id. Put the exact
		# resource shown on the clicked card first so cursed/duplicate variants
		# cannot remove a different saved entry.
		_wish_prioritize_exact_shop_entry(shop_item, player_index)
		_wish_remove_purchased_item_lock(shop_item, player_index)

	if shop_item.value > 0 and RunData.wish_get_discount(player_index) > 0:
		RunData.wish_consume_discount(player_index)

	.on_shop_item_bought(shop_item, player_index)
	if bought_lamp:
		RunData.wish_mark_lamp_bought_this_shop(player_index)
		_get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))
		ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)
	if bought_corruption:
		var cursed_names = RunData.wish_corruption_result.get(player_index, [])
		RunData.wish_corruption_result.erase(player_index)
		var gear = _get_gear_container(player_index)
		gear.set_items_data(RunData.get_player_items(player_index))
		gear.set_weapons_data(RunData.get_player_weapons(player_index))
		_update_stats(player_index)
		ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)
		_wish_show_corruption_result(cursed_names, player_index)
	_wish_refresh_action(player_index)


func _wish_show_corruption_result(cursed_names: Array, player_index: int) -> void:
	var dialog = AcceptDialog.new()
	dialog.window_title = tr("ITEM_WISH_FOR_CORRUPTION")
	dialog.dialog_text = tr("WISH_FOR_CORRUPTION_NONE") if cursed_names.empty() else tr("WISH_FOR_CORRUPTION_RESULT")
	for item_name in cursed_names:
		dialog.dialog_text += "\n" + str(item_name)
	dialog.connect("popup_hide", self, "_on_wish_corruption_result_closed", [dialog, player_index])
	add_child(dialog)
	dialog.popup_centered(Vector2(560, 180))
	dialog.get_ok().grab_focus()


func _on_wish_corruption_result_closed(dialog: AcceptDialog, player_index: int) -> void:
	dialog.queue_free()
	call_deferred("_wish_restore_shop_focus", player_index)


func buy_item(item_data: ItemData, player_index: int) -> void:
	if item_data == null or item_data.my_id != LAMP_ID:
		.buy_item(item_data, player_index)
		return

	# Lamp is repeatable between shop visits, but clone-on-purchase effects must
	# not turn one card into several Lamps (and several Wish resources).
	RunData.add_item(item_data, player_index)
	_get_gear_container(player_index).items_container._elements.add_element(item_data, true)


func _wish_get_item_price_at_wave(item: ItemData, player_index: int, wave_value: int) -> int:
	var value = ItemService.get_value(wave_value, item.value, player_index, true, false, item.my_id_hash)
	var discount = RunData.wish_get_discount(player_index)
	if value > 0 and discount > 0:
		value = max(1, ceil(value * (1.0 - discount / 100.0))) as int
	return value


func _wish_get_estimated_delivery_price(item: ItemData, player_index: int) -> int:
	return _wish_get_item_price_at_wave(item, player_index, RunData.current_wave)


func on_shop_item_banned(shop_item: ShopItem, player_index: int) -> void:
	if shop_item != null and shop_item.item_data != null and shop_item.item_data.my_id == LAMP_ID:
		return
	var has_wish_shop = RunData.wish_has_access(player_index)
	if has_wish_shop:
		_wish_prioritize_exact_shop_entry(shop_item, player_index)
		_wish_remove_banned_item_locks(shop_item, player_index)
	.on_shop_item_banned(shop_item, player_index)
	_wish_refresh_action(player_index)


func _wish_prioritize_exact_shop_entry(shop_item: ShopItem, player_index: int) -> void:
	if shop_item == null or shop_item.item_data == null:
		return
	var player_shop_items = _shop_items[player_index]
	for entry_index in player_shop_items.size():
		var entry = player_shop_items[entry_index]
		if not _wish_is_placeholder_entry(entry) and entry[0] == shop_item.item_data:
			if entry_index > 0:
				player_shop_items.remove(entry_index)
				player_shop_items.push_front(entry)
			return


func _wish_remove_purchased_item_lock(shop_item: ShopItem, player_index: int) -> void:
	if shop_item == null or shop_item.item_data == null or not shop_item.locked:
		return
	RunData.unlock_player_shop_item(shop_item.item_data, player_index)


func _wish_remove_banned_item_locks(shop_item: ShopItem, player_index: int) -> void:
	if shop_item == null or shop_item.item_data == null:
		return
	var locked_items = RunData.locked_shop_items[player_index]
	for entry_index in range(locked_items.size() - 1, -1, -1):
		var entry = locked_items[entry_index]
		if entry != null and entry is Array and not entry.empty() and entry[0] != null and entry[0].my_id == shop_item.item_data.my_id:
			locked_items.remove(entry_index)


func _on_GoButton_pressed(player_index: int) -> void:
	var will_leave = not get_tree().paused and not _player_pressed_go_button[player_index]
	if will_leave:
		for other_player_index in RunData.get_player_count():
			if other_player_index != player_index and not _player_pressed_go_button[other_player_index]:
				will_leave = false
				break
	if will_leave:
		for leaving_player_index in RunData.get_player_count():
			RunData.wish_leave_shop(leaving_player_index)
	._on_GoButton_pressed(player_index)


func _on_gold_changed(new_value: int, player_index: int) -> void:
	._on_gold_changed(new_value, player_index)
	_wish_refresh_action(player_index)


func _on_wish_shop_capacity_changed(player_index: int) -> void:
	_wish_refresh_action(player_index)


func _wish_migrate_legacy_shop(player_index: int) -> bool:
	if not RunData.wish_needs_external_layout_migration(player_index):
		return false
	var old_layout_version = int(RunData.wish_get_player_state(player_index).layout_version)
	RunData.wish_mark_external_layout_migrated(player_index)
	if old_layout_version >= 2 or not RunData.wish_has_access(player_index):
		return false

	# Every old Wish shop contained only three normal offers plus either a
	# placeholder or the wished delivery. Re-roll the row once, for free, so an
	# in-progress save immediately returns to four native shop offers.
	var locked_items = RunData.get_player_locked_shop_items(player_index)
	.fill_shop_items(locked_items, player_index, false)
	_get_shop_items_container(player_index).set_shop_items(_shop_items[player_index])
	ModLoaderLog.info("Migrated player " + str(player_index + 1) + " from the legacy Wish slot layout", "Careful-Wish")
	return true


func _wish_create_action_button(player_index: int) -> void:
	var reroll_button = _get_reroll_button(player_index)
	_wish_reroll_left_neighbors[player_index] = reroll_button.focus_neighbor_left
	var header = reroll_button.get_parent()
	# Wish and Crooked Wish can coexist. Keep each action to one icon-sized
	# control so the native shop header still fits at narrow resolutions.
	var button = Button.new()
	button.name = "WishActionP" + str(player_index + 1)
	button.rect_min_size = Vector2(88, 65) if RunData.is_coop_run else Vector2(128, 82)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.expand_icon = true
	button.connect("pressed", self, "_on_wish_action_pressed", [player_index])
	header.add_child(button)
	header.move_child(button, reroll_button.get_index())
	_wish_action_buttons[player_index] = button


func _crooked_create_action_button(player_index: int) -> void:
	var reroll_button = _get_reroll_button(player_index)
	var header = reroll_button.get_parent()

	var button = Button.new()
	button.name = "CrookedWishActionP" + str(player_index + 1)
	button.rect_min_size = Vector2(88, 65) if RunData.is_coop_run else Vector2(128, 82)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.expand_icon = true
	button.connect("pressed", self, "_on_crooked_action_pressed", [player_index])
	header.add_child(button)
	header.move_child(button, reroll_button.get_index())
	_crooked_action_buttons[player_index] = button


func _wish_update_action_focus(player_index: int) -> void:
	var reroll_button = _get_reroll_button(player_index)
	var wish_button = _wish_action_buttons[player_index]
	var crooked_button = _crooked_action_buttons[player_index]
	var actions = []
	if wish_button != null and wish_button.visible and not wish_button.disabled:
		actions.push_back(wish_button)
	if crooked_button != null and crooked_button.visible and not crooked_button.disabled:
		actions.push_back(crooked_button)

	for button in [wish_button, crooked_button]:
		if button != null:
			button.focus_neighbor_left = NodePath("")
			button.focus_neighbor_right = NodePath("")
	reroll_button.focus_neighbor_left = _wish_reroll_left_neighbors[player_index]

	for action_index in actions.size():
		var action = actions[action_index]
		if action_index > 0:
			action.focus_neighbor_left = action.get_path_to(actions[action_index - 1])
		var right_control = actions[action_index + 1] if action_index + 1 < actions.size() else reroll_button
		action.focus_neighbor_right = action.get_path_to(right_control)
	if not actions.empty():
		reroll_button.focus_neighbor_left = reroll_button.get_path_to(actions.back())


func _wish_refresh_action(player_index: int) -> void:
	_crooked_refresh_action(player_index)
	var button = _wish_action_buttons[player_index]
	if button == null:
		return
	button.visible = RunData.wish_has_access(player_index)
	if not button.visible:
		_wish_update_action_focus(player_index)
		return
	var resource_count = RunData.wish_get_resource_count(player_index)
	button.text = str(resource_count)
	button.icon = ItemService.wish_get_active_lamp_icon() if resource_count > 0 else ItemService.wish_get_used_lamp_icon()
	var phase = RunData.wish_get_phase(player_index)
	button.disabled = true
	button.hint_tooltip = tr("WISH_ACTION")

	match phase:
		RunData.WISH_AVAILABLE, RunData.WISH_QUEUED_CURRENT_SHOP:
			var cost = RunData.wish_get_cost(player_index)
			var queue_preview = _wish_get_queue_preview(player_index)
			if not queue_preview.empty():
				button.hint_tooltip += "\n" + queue_preview
			button.hint_tooltip += "\n"
			button.hint_tooltip += Text.text("WISH_COST", [str(cost)]) + "\n" + Text.text("WISH_RESOURCE_COUNT", [str(RunData.wish_get_resource_count(player_index))])
			if RunData.wish_get_available_delivery_slots(player_index) <= 0:
				button.hint_tooltip += "\n" + tr("WISH_NO_REROLL_SLOTS")
			elif RunData.wish_get_resource_count(player_index) <= 0:
				button.hint_tooltip += "\n" + tr("WISH_NO_RESOURCES")
			elif RunData.get_player_gold(player_index) < cost:
				button.hint_tooltip += "\n" + Text.text("WISH_NEED_MATERIALS", [str(cost)])
			else:
				button.disabled = false
		_:
			button.hint_tooltip += "\n" + tr("WISH_QUEUE_MIGRATING")
	_wish_update_action_focus(player_index)


func _crooked_refresh_action(player_index: int) -> void:
	var button = _crooked_action_buttons[player_index]
	if button == null:
		return
	button.visible = RunData.crooked_has_access(player_index)
	if not button.visible:
		return
	button.disabled = true
	var charges = RunData.crooked_get_charges(player_index)
	button.text = str(charges)
	button.icon = ItemService.wish_get_paw_icon(charges)
	button.hint_tooltip = tr("CROOKED_ACTION") + "\n" + Text.text("CROOKED_CHARGES", [str(charges)]) + "\n" + tr("CROOKED_CONSEQUENCE")
	if charges <= 0:
		button.hint_tooltip += "\n" + tr("CROOKED_NO_CHARGES")
	elif not RunData.wish_can_queue_item(player_index):
		button.hint_tooltip += "\n" + tr("WISH_NO_REROLL_SLOTS")
	else:
		button.disabled = false

	var queued = RunData.crooked_get_queued_calamities()
	if not queued.empty():
		var names = []
		var details = []
		for calamity_id in queued:
			names.push_back(_crooked_get_calamity_name(str(calamity_id)))
			details.push_back(_crooked_get_calamity_name(str(calamity_id)) + ": " + _crooked_get_calamity_description(str(calamity_id)))
		button.hint_tooltip += "\n" + Text.text("CROOKED_BADGE", [PoolStringArray(names).join(" + ")])
		button.hint_tooltip += "\n" + PoolStringArray(details).join("\n")


func _wish_get_queue_preview(player_index: int) -> String:
	var lines = []
	for item_id_value in RunData.wish_get_pending_item_ids(player_index):
		var item = _wish_find_item(str(item_id_value))
		if item != null:
			lines.push_back(Text.text("WISH_QUEUE_ITEM", [item.get_name_text(), str(_wish_get_estimated_delivery_price(item, player_index))]))
	return PoolStringArray(lines).join("\n")


func _wish_create_picker(player_index: int) -> void:
	var popup = PopupPanel.new()
	popup.name = "WishPickerP" + str(player_index + 1)
	popup.rect_min_size = Vector2(940, 700)
	popup.connect("popup_hide", self, "_on_wish_picker_closed", [player_index])
	add_child(popup)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 18)
	margin.add_constant_override("margin_top", 18)
	margin.add_constant_override("margin_right", 18)
	margin.add_constant_override("margin_bottom", 18)
	popup.add_child(margin)

	var column = VBoxContainer.new()
	column.add_constant_override("separation", 10)
	margin.add_child(column)

	var title = Label.new()
	title.text = tr("WISH_PICKER_TITLE")
	title.align = Label.ALIGN_CENTER
	column.add_child(title)

	var cost_label = Label.new()
	cost_label.align = Label.ALIGN_CENTER
	column.add_child(cost_label)

	var search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = tr("WISH_SEARCH")
	search.connect("text_changed", self, "_on_wish_search_changed", [player_index])
	search.connect("gui_input", self, "_on_wish_picker_gui_input", [player_index])
	column.add_child(search)

	var scroll = ScrollContainer.new()
	scroll.rect_min_size = Vector2(0, 470)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_constant_override("hseparation", 8)
	grid.add_constant_override("vseparation", 8)
	scroll.add_child(grid)

	var confirm = Button.new()
	confirm.name = "Confirm"
	confirm.text = tr("WISH_CHOOSE")
	confirm.disabled = true
	confirm.connect("pressed", self, "_on_wish_confirm_pressed", [player_index])
	confirm.connect("gui_input", self, "_on_wish_picker_gui_input", [player_index])
	column.add_child(confirm)

	var cancel = Button.new()
	cancel.name = "Cancel"
	cancel.text = tr("WISH_CANCEL")
	cancel.connect("pressed", self, "_on_wish_picker_cancel_pressed", [player_index])
	cancel.connect("gui_input", self, "_on_wish_picker_gui_input", [player_index])
	column.add_child(cancel)

	_wish_picker_popups[player_index] = popup
	_wish_picker_titles[player_index] = title
	_wish_picker_lists[player_index] = grid
	_wish_picker_cost_labels[player_index] = cost_label
	_wish_picker_confirm_buttons[player_index] = confirm
	_wish_picker_cancel_buttons[player_index] = cancel
	_wish_picker_search_fields[player_index] = search


func _on_wish_action_pressed(player_index: int) -> void:
	var phase = RunData.wish_get_phase(player_index)
	if phase != RunData.WISH_AVAILABLE and phase != RunData.WISH_QUEUED_CURRENT_SHOP:
		return
	if not RunData.wish_can_queue_item(player_index):
		return
	if RunData.wish_get_resource_count(player_index) <= 0:
		return
	var cost = RunData.wish_get_cost(player_index)
	if RunData.get_player_gold(player_index) < cost:
		return
	var popup = _wish_picker_popups[player_index]
	popup.set_meta("wish_source", "standard")
	popup.set_meta("selected_item_id", "")
	popup.set_meta("restore_focus_on_hide", true)
	_wish_picker_titles[player_index].text = tr("WISH_PICKER_TITLE")
	_wish_picker_search_fields[player_index].clear()
	_wish_picker_confirm_buttons[player_index].disabled = true
	_wish_picker_confirm_buttons[player_index].text = tr("WISH_CHOOSE")
	_wish_picker_cost_labels[player_index].text = Text.text("WISH_WISH_FEE", [str(cost)]) + "\n" + Text.text("WISH_RESOURCE_COUNT", [str(RunData.wish_get_resource_count(player_index))])
	_wish_picker_return_focus[player_index] = _wish_action_buttons[player_index]
	_wish_rebuild_picker(player_index)
	popup.popup_centered(Vector2(940, 700))
	call_deferred("_wish_focus_first_card", player_index)


func _on_crooked_action_pressed(player_index: int) -> void:
	if not RunData.crooked_has_access(player_index) or RunData.crooked_get_charges(player_index) <= 0:
		return
	if not RunData.wish_can_queue_item(player_index):
		return
	var popup = _wish_picker_popups[player_index]
	popup.set_meta("wish_source", "crooked")
	popup.set_meta("selected_item_id", "")
	popup.set_meta("restore_focus_on_hide", true)
	_wish_picker_titles[player_index].text = tr("CROOKED_PICKER_TITLE")
	_wish_picker_search_fields[player_index].clear()
	_wish_picker_confirm_buttons[player_index].disabled = true
	_wish_picker_confirm_buttons[player_index].text = tr("WISH_CHOOSE")
	_wish_picker_cost_labels[player_index].text = Text.text("CROOKED_CHARGES", [str(RunData.crooked_get_charges(player_index))]) + "\n" + tr("CROOKED_CONSEQUENCE")
	_wish_picker_return_focus[player_index] = _crooked_action_buttons[player_index]
	_wish_rebuild_picker(player_index)
	popup.popup_centered(Vector2(940, 700))
	call_deferred("_wish_focus_first_card", player_index)


func _wish_rebuild_picker(player_index: int) -> void:
	var list = _wish_picker_lists[player_index]
	var is_crooked = str(_wish_picker_popups[player_index].get_meta("wish_source")) == "crooked"
	for child in list.get_children():
		child.free()

	var candidates = []
	for item in ItemService.items:
		if _wish_is_item_eligible(item, player_index, false):
			candidates.push_back(item)
	candidates.sort_custom(self, "_wish_sort_items")

	for item_index in candidates.size():
		var item = candidates[item_index]
		var waves_until_unlock = _wish_waves_until_tier(item.tier, is_crooked, player_index)
		var card = Button.new()
		card.name = "WishCard" + str(item_index)
		card.rect_min_size = Vector2(130, 140)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.rect_clip_content = true
		card.disabled = waves_until_unlock > 0
		card.hint_tooltip = item.get_name_text()
		card.set_meta("item_id", item.my_id)
		card.set_meta("search_text", item.get_name_text().to_lower())
		_wish_apply_card_tier_style(card, item.tier)
		if not card.disabled:
			card.connect("pressed", self, "_on_wish_choice_pressed", [item.my_id, player_index])
			card.connect("gui_input", self, "_on_wish_picker_gui_input", [player_index])

		var card_content = VBoxContainer.new()
		card.add_child(card_content)
		card_content.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		card_content.margin_left = 8
		card_content.margin_top = 7
		card_content.margin_right = -8
		card_content.margin_bottom = -7
		card_content.rect_clip_content = true
		card_content.add_constant_override("separation", 2)
		card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon = TextureRect.new()
		icon.rect_min_size = Vector2(48, 48)
		icon.texture = item.get_icon()
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(icon)

		var name_label = Label.new()
		name_label.name = "ItemName"
		name_label.text = item.get_name_text()
		name_label.align = Label.ALIGN_CENTER
		name_label.valign = Label.VALIGN_CENTER
		name_label.autowrap = true
		name_label.clip_text = true
		name_label.rect_min_size = Vector2(0, 42)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_font_override("font", WISH_CARD_FONT)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(name_label)

		var unlock_label = Label.new()
		unlock_label.name = "UnlockStatus"
		unlock_label.align = Label.ALIGN_CENTER
		unlock_label.valign = Label.VALIGN_CENTER
		unlock_label.autowrap = true
		unlock_label.clip_text = true
		unlock_label.rect_min_size = Vector2(0, 30)
		unlock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unlock_label.add_font_override("font", WISH_CARD_FONT)
		unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if waves_until_unlock == 1:
			unlock_label.text = tr("WISH_UNLOCKS_NEXT_WAVE")
		elif waves_until_unlock > 1:
			unlock_label.text = Text.text("WISH_UNLOCKS_IN_WAVES", [str(waves_until_unlock)])
		unlock_label.visible = waves_until_unlock > 0
		unlock_label.add_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		card_content.add_child(unlock_label)
		list.add_child(card)
	_wish_update_picker_focus(player_index)


func _wish_update_picker_focus(player_index: int) -> void:
	var search = _wish_picker_search_fields[player_index]
	var confirm = _wish_picker_confirm_buttons[player_index]
	var cancel = _wish_picker_cancel_buttons[player_index]
	var cards = []
	for child in _wish_picker_lists[player_index].get_children():
		if child is Button and child.visible and not child.disabled:
			cards.push_back(child)

	for control in cards + [search, confirm, cancel]:
		control.focus_neighbor_left = NodePath("")
		control.focus_neighbor_top = NodePath("")
		control.focus_neighbor_right = NodePath("")
		control.focus_neighbor_bottom = NodePath("")

	var bottom_control = confirm if not confirm.disabled else cancel
	search.focus_neighbor_left = search.get_path_to(search)
	search.focus_neighbor_top = search.get_path_to(cancel)
	search.focus_neighbor_right = search.get_path_to(search)
	search.focus_neighbor_bottom = search.get_path_to(cards[0] if not cards.empty() else bottom_control)
	confirm.focus_neighbor_left = confirm.get_path_to(confirm)
	confirm.focus_neighbor_top = confirm.get_path_to(cards.back() if not cards.empty() else search)
	confirm.focus_neighbor_right = confirm.get_path_to(confirm)
	confirm.focus_neighbor_bottom = confirm.get_path_to(cancel)
	cancel.focus_neighbor_left = cancel.get_path_to(cancel)
	cancel.focus_neighbor_top = cancel.get_path_to(confirm if not confirm.disabled else (cards.back() if not cards.empty() else search))
	cancel.focus_neighbor_right = cancel.get_path_to(cancel)
	cancel.focus_neighbor_bottom = cancel.get_path_to(search)

	var columns = _wish_picker_lists[player_index].columns
	for card_index in cards.size():
		var card = cards[card_index]
		var column = card_index % columns
		var row_start = card_index - column
		var row_end = min(row_start + columns, cards.size()) - 1
		var left_card = cards[card_index - 1] if card_index > row_start else card
		var right_card = cards[card_index + 1] if card_index < row_end else card
		var up_control = cards[card_index - columns] if card_index >= columns else search
		var down_index = card_index + columns
		var down_control = cards[down_index] if down_index < cards.size() else bottom_control
		card.focus_neighbor_left = card.get_path_to(left_card)
		card.focus_neighbor_top = card.get_path_to(up_control)
		card.focus_neighbor_right = card.get_path_to(right_card)
		card.focus_neighbor_bottom = card.get_path_to(down_control)


func _wish_focus_first_card(player_index: int) -> void:
	var popup = _wish_picker_popups[player_index]
	if popup == null or not popup.visible:
		return
	for child in _wish_picker_lists[player_index].get_children():
		if child is Button and child.visible and not child.disabled:
			child.grab_focus()
			return
	_wish_picker_cancel_buttons[player_index].grab_focus()


func _on_wish_picker_gui_input(event: InputEvent, player_index: int) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		_on_wish_picker_cancel_pressed(player_index)


func _on_wish_picker_cancel_pressed(player_index: int) -> void:
	var popup = _wish_picker_popups[player_index]
	if popup != null and popup.visible:
		popup.hide()


func _on_wish_picker_closed(player_index: int) -> void:
	var popup = _wish_picker_popups[player_index]
	if popup != null and popup.has_meta("restore_focus_on_hide") and not bool(popup.get_meta("restore_focus_on_hide")):
		popup.set_meta("restore_focus_on_hide", true)
		return
	call_deferred("_wish_restore_shop_focus", player_index)


func _wish_restore_shop_focus(player_index: int) -> void:
	var popup = _wish_picker_popups[player_index]
	if popup != null and popup.visible:
		return
	var return_control = _wish_picker_return_focus[player_index]
	if return_control == null or not is_instance_valid(return_control) or not return_control.visible or return_control.disabled:
		return_control = _get_reroll_button(player_index)
	if return_control != null and is_instance_valid(return_control) and return_control.visible and not return_control.disabled:
		return_control.grab_focus()


func _wish_apply_card_tier_style(card: Button, tier: int) -> void:
	var tier_color = ItemService.get_color_from_tier(tier)
	var dark = Color(0.035, 0.035, 0.045, 1.0)
	var normal_color = dark.linear_interpolate(tier_color, 0.42)
	var hover_color = dark.linear_interpolate(tier_color, 0.62)
	var pressed_color = dark.linear_interpolate(tier_color, 0.76)
	var disabled_color = dark.linear_interpolate(tier_color, 0.24)
	card.add_stylebox_override("normal", _wish_card_style(normal_color, tier_color))
	card.add_stylebox_override("hover", _wish_card_style(hover_color, tier_color))
	card.add_stylebox_override("pressed", _wish_card_style(pressed_color, Color.white))
	card.add_stylebox_override("focus", _wish_card_style(hover_color, Color.white))
	card.add_stylebox_override("disabled", _wish_card_style(disabled_color, tier_color.darkened(0.35)))


func _wish_card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _on_wish_search_changed(search_text: String, player_index: int) -> void:
	var normalized = search_text.strip_edges().to_lower()
	for row in _wish_picker_lists[player_index].get_children():
		row.visible = normalized.empty() or normalized in str(row.get_meta("search_text"))
	_wish_update_picker_focus(player_index)


func _on_wish_choice_pressed(item_id: String, player_index: int) -> void:
	var item = _wish_find_item(item_id)
	if item == null:
		return
	var popup = _wish_picker_popups[player_index]
	popup.set_meta("selected_item_id", item_id)
	var confirm = _wish_picker_confirm_buttons[player_index]
	var is_crooked = str(popup.get_meta("wish_source")) == "crooked"
	if is_crooked:
		confirm.text = Text.text("CROOKED_CONFIRM", [item.get_name_text()])
	else:
		confirm.text = Text.text("WISH_CONFIRM", [item.get_name_text(), str(RunData.wish_get_cost(player_index))])
	confirm.disabled = false
	var estimated_price = _wish_get_estimated_delivery_price(item, player_index)
	if is_crooked:
		_wish_picker_cost_labels[player_index].text = Text.text("WISH_ESTIMATED_ITEM_COST", [str(estimated_price)]) + "\n" + Text.text("CROOKED_CHARGES", [str(RunData.crooked_get_charges(player_index))]) + "\n" + tr("CROOKED_CONSEQUENCE")
	else:
		_wish_picker_cost_labels[player_index].text = Text.text("WISH_WISH_FEE", [str(RunData.wish_get_cost(player_index))]) + "\n" + Text.text("WISH_ESTIMATED_ITEM_COST", [str(estimated_price)]) + "\n" + Text.text("WISH_RESOURCE_COUNT", [str(RunData.wish_get_resource_count(player_index))])
	_wish_update_picker_focus(player_index)


func _on_wish_confirm_pressed(player_index: int) -> void:
	var popup = _wish_picker_popups[player_index]
	if str(popup.get_meta("wish_source")) == "crooked":
		_on_crooked_confirm_pressed(player_index)
		return
	var item_id = str(popup.get_meta("selected_item_id"))
	var item = _wish_find_item(item_id)
	var cost = RunData.wish_get_cost(player_index)
	if item == null or not _wish_is_item_eligible(item, player_index):
		_wish_picker_cost_labels[player_index].text = tr("WISH_SELECTION_INVALID")
		return
	var phase = RunData.wish_get_phase(player_index)
	if phase != RunData.WISH_AVAILABLE and phase != RunData.WISH_QUEUED_CURRENT_SHOP:
		_wish_picker_cost_labels[player_index].text = tr("WISH_SELECTION_INVALID")
		return
	if not RunData.wish_can_queue_item(player_index):
		_wish_picker_cost_labels[player_index].text = tr("WISH_NO_REROLL_SLOTS")
		return
	if RunData.get_player_gold(player_index) < cost:
		_wish_picker_cost_labels[player_index].text = Text.text("WISH_NEED_MATERIALS", [str(cost)])
		return
	if RunData.wish_get_resource_count(player_index) <= 0:
		_wish_picker_cost_labels[player_index].text = tr("WISH_NO_RESOURCES")
		return

	if not RunData.wish_consume_resource(player_index):
		_wish_picker_cost_labels[player_index].text = tr("WISH_NO_RESOURCES")
		return
	RunData.remove_gold(cost, player_index)
	var queued = RunData.wish_queue_item(item_id, player_index)
	assert(queued)
	popup.hide()
	_get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))
	_wish_refresh_action(player_index)
	ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)


func _on_crooked_confirm_pressed(player_index: int) -> void:
	var popup = _wish_picker_popups[player_index]
	var item_id = str(popup.get_meta("selected_item_id"))
	var item = _wish_find_item(item_id)
	if item == null or not _wish_is_item_eligible(item, player_index, true, true):
		_wish_picker_cost_labels[player_index].text = tr("WISH_SELECTION_INVALID")
		return
	if RunData.crooked_get_charges(player_index) <= 0:
		_wish_picker_cost_labels[player_index].text = tr("CROOKED_NO_CHARGES")
		return
	if not RunData.wish_can_queue_item(player_index):
		_wish_picker_cost_labels[player_index].text = tr("WISH_NO_REROLL_SLOTS")
		return
	if not RunData.crooked_consume_charge(player_index):
		_wish_picker_cost_labels[player_index].text = tr("CROOKED_NO_CHARGES")
		return
	var queued = RunData.wish_queue_crooked_item(item_id, player_index)
	assert(queued)
	var calamity_id = RunData.crooked_queue_random_calamity()
	popup.set_meta("restore_focus_on_hide", false)
	popup.hide()
	_get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))
	_wish_refresh_action(player_index)
	ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)
	_crooked_show_reveal(calamity_id, player_index)


func _crooked_show_reveal(calamity_id: String, player_index: int) -> void:
	var dialog = AcceptDialog.new()
	dialog.window_title = tr("CROOKED_REVEAL_TITLE")
	dialog.dialog_text = Text.text("CROOKED_REVEAL", [_crooked_get_calamity_name(calamity_id)]) + "\n\n" + _crooked_get_calamity_description(calamity_id)
	dialog.connect("popup_hide", self, "_on_crooked_reveal_closed", [dialog, player_index])
	add_child(dialog)
	dialog.popup_centered(Vector2(620, 260))
	dialog.get_ok().grab_focus()


func _on_crooked_reveal_closed(dialog: AcceptDialog, player_index: int) -> void:
	dialog.queue_free()
	call_deferred("_wish_restore_shop_focus", player_index)


func _crooked_get_calamity_name(calamity_id: String) -> String:
	return tr("CALAMITY_" + calamity_id.to_upper() + "_NAME")


func _crooked_get_calamity_description(calamity_id: String) -> String:
	return tr("CALAMITY_" + calamity_id.to_upper() + "_DESC")


func _wish_is_item_eligible(item, player_index: int, check_tier: bool = true, is_crooked: bool = false) -> bool:
	if item == null or not item is ItemData:
		return false
	if item.my_id == LAMP_ID or item.my_id == PLACEHOLDER_ID:
		return false
	if not item.can_be_looted or item.max_nb == 0:
		return false
	if not ProgressData.items_unlocked.has(item.my_id_hash):
		return false
	if check_tier and item.tier > _wish_max_tier_for_next_reroll(is_crooked, player_index):
		return false

	if _wish_is_item_banned_for_player(item, player_index):
		return false

	var character = RunData.get_player_character(player_index)
	if character != null:
		if character.banned_items.has(item.my_id):
			return false
		for banned_group in character.banned_item_groups:
			if ItemService.item_groups.has(banned_group) and ItemService.item_groups[banned_group].has(item.my_id):
				return false

	var removed_tags = RunData.get_player_effect(Keys.remove_shop_items_hash, player_index)
	for removed_tag_hash in removed_tags:
		var removed_tag = Keys.hash_to_string.get(removed_tag_hash, "")
		if item.tags.has(removed_tag):
			return false

	if RunData.current_wave >= RunData.nb_of_waves:
		if ItemService.banned_items_for_endless.has(item.my_id) or ItemService.banned_items_for_endless.has(item.my_id_hash):
			return false

	if item.max_nb != -1:
		var count = RunData.get_nb_item(item.my_id_hash, player_index)
		for shop_entry in _shop_items[player_index]:
			if shop_entry != null and shop_entry is Array and not shop_entry.empty() and shop_entry[0] != null and shop_entry[0].my_id_hash == item.my_id_hash:
				count += 1
		for queued_item_id in RunData.wish_get_pending_item_ids(player_index):
			if str(queued_item_id) == item.my_id:
				count += 1
		if count >= item.max_nb:
			return false
	return true


func _wish_is_item_banned_for_player(item: ItemData, player_index: int) -> bool:
	# Brotato accepts both IDs and hashes here, while older/JSON-restored run
	# state can contain a numeric hash as a real. Normalize all supported forms
	# so Wish follows the same ban list as ordinary shop rolls.
	for banned_id in RunData.players_data[player_index].banned_items:
		if banned_id is String:
			if banned_id == item.my_id or Keys.generate_hash(banned_id) == item.my_id_hash:
				return true
		elif typeof(banned_id) == TYPE_INT or typeof(banned_id) == TYPE_REAL:
			if int(banned_id) == item.my_id_hash:
				return true
	return false


func _wish_max_tier_for_next_reroll(is_crooked: bool = false, player_index: int = 0) -> int:
	var target_wave = RunData.current_wave
	var unlock_waves = _wish_get_tier_unlock_waves(is_crooked, player_index)
	var uncommon_wave = int(unlock_waves[ItemParentData.Tier.UNCOMMON])
	var rare_wave = int(unlock_waves[ItemParentData.Tier.RARE])
	var legendary_wave = int(unlock_waves[ItemParentData.Tier.LEGENDARY])
	if target_wave >= legendary_wave:
		return ItemParentData.Tier.LEGENDARY
	if target_wave >= rare_wave:
		return ItemParentData.Tier.RARE
	if target_wave >= uncommon_wave:
		return ItemParentData.Tier.UNCOMMON
	return ItemParentData.Tier.COMMON


func _wish_waves_until_tier(tier: int, is_crooked: bool = false, player_index: int = 0) -> int:
	var unlock_waves = _wish_get_tier_unlock_waves(is_crooked, player_index)
	var unlock_wave = int(unlock_waves.get(tier, 0))
	var target_wave = RunData.current_wave
	return max(0, unlock_wave - target_wave) as int


func _wish_get_tier_unlock_waves(is_crooked: bool, player_index: int) -> Dictionary:
	if is_crooked:
		return {
			ItemParentData.Tier.UNCOMMON: 1,
			ItemParentData.Tier.RARE: 3,
			ItemParentData.Tier.LEGENDARY: 6
		}

	var character = RunData.get_player_character(player_index)
	if character != null and character.my_id == DJINN_ID:
		return {
			ItemParentData.Tier.UNCOMMON: 1,
			ItemParentData.Tier.RARE: 3,
			ItemParentData.Tier.LEGENDARY: 6
		}

	return {
		ItemParentData.Tier.UNCOMMON: 2,
		ItemParentData.Tier.RARE: 4,
		ItemParentData.Tier.LEGENDARY: 8
	}


func _wish_tier_color(tier: int) -> Color:
	match tier:
		ItemParentData.Tier.UNCOMMON:
			return ItemService.TIER_UNCOMMON_COLOR
		ItemParentData.Tier.RARE:
			return ItemService.TIER_RARE_COLOR
		ItemParentData.Tier.LEGENDARY:
			return ItemService.TIER_LEGENDARY_COLOR
	return Color.white


func _wish_sort_items(a, b) -> bool:
	if a.tier != b.tier:
		return a.tier < b.tier
	return a.get_name_text().naturalnocasecmp_to(b.get_name_text()) < 0


func _wish_is_placeholder_entry(entry) -> bool:
	return entry == null or not entry is Array or entry.empty() or entry[0] == null or entry[0].my_id == PLACEHOLDER_ID


func _wish_find_item(item_id: String):
	for item in ItemService.items:
		if item.my_id == item_id:
			return item
	return null
