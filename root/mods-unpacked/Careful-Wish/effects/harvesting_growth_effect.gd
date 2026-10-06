extends "res://items/global/effect.gd"

# Effect.value is an integer in Brotato. Store tenths of a percentage point
# here, then apply the fractional bonus to the native Harvesting growth rate.
const TENTHS_PER_PERCENT = 10.0


static func get_id() -> String:
	return "wish_harvesting_growth_effect"


func _init() -> void:
	key = "harvesting_growth"
	text_key = "WISH_FOR_GROWTH_EFFECT"
	value = 3
	effect_sign = Effect.Sign.POSITIVE
	_generate_hashes()


func apply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	effects[key_hash] = float(effects.get(key_hash, 0)) + float(value) / TENTHS_PER_PERCENT
	Utils.reset_stat_cache(player_index)


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	effects[key_hash] = float(effects.get(key_hash, 0)) - float(value) / TENTHS_PER_PERCENT
	Utils.reset_stat_cache(player_index)


func get_args(_player_index: int) -> Array:
	return [str(float(value) / TENTHS_PER_PERCENT)]
