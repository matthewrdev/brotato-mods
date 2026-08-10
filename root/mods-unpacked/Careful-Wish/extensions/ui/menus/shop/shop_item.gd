extends "res://ui/menus/shop/shop_item.gd"

const PLACEHOLDER_ID = "item_wish_empty_slot"
const LAMP_ID = "item_magic_lamp"


func set_shop_item(p_item_data: ItemParentData, p_wave_value: int = RunData.current_wave) -> void:
	if p_item_data != null and p_item_data.my_id == PLACEHOLDER_ID:
		item_data = p_item_data
		wave_value = p_wave_value
		deactivate()
		return

	.set_shop_item(p_item_data, p_wave_value)
	if p_item_data.my_id == LAMP_ID:
		# Max one Lamp may be acquired in this shop visit, even when an owned
		# effect would normally duplicate an item card on purchase.
		_button.remove_additional_icon()
		_item_description.set_item(p_item_data, player_index, 1)
		manage_ban_button_visibility()
	var discount = RunData.wish_get_discount(player_index)
	if discount > 0 and value > 0:
		value = max(1, ceil(value * (1.0 - discount / 100.0))) as int
		_button.set_value(value, RunData.get_player_currency(player_index))


func change_lock_status(button_pressed: bool) -> void:
	if button_pressed and item_data != null and item_data.my_id == LAMP_ID:
		_lock_button.set_pressed_no_signal(false)
		return
	if button_pressed and not locked and not RunData.wish_can_lock_shop_item(player_index):
		_lock_button.set_pressed_no_signal(false)
		return
	var was_locked = locked
	.change_lock_status(button_pressed)
	if was_locked != locked:
		RunData.emit_signal("wish_shop_capacity_changed", player_index)


func manage_ban_button_visibility() -> void:
	if item_data != null and item_data.my_id == LAMP_ID:
		_ban_button.disable()
		_ban_button.hide()
		return
	.manage_ban_button_visibility()


func ban_item() -> void:
	if item_data != null and item_data.my_id == LAMP_ID:
		return
	.ban_item()


func _on_BanButton_button_down():
	if item_data != null and item_data.my_id == LAMP_ID:
		return
	._on_BanButton_button_down()


func _release_BanButton():
	if item_data != null and item_data.my_id == LAMP_ID:
		return
	._release_BanButton()


func _on_BanButton_pressed():
	if item_data != null and item_data.my_id == LAMP_ID:
		return
	._on_BanButton_pressed()
