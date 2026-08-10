extends "res://main.gd"


func _ready() -> void:
	# Native Brotato deliberately prevents Bullet Hell and fog from sharing a
	# wave. Crooked Wishes may stack Night and Frenzy, so restore the native
	# environmental-projectile controller after Main has initialized the fog.
	if RunData.crooked_has_active_calamity(RunData.CALAMITY_FRENZY) and _is_fog_wave:
		var wave = min(RunData.current_wave, 20)
		var bullet_hell: BulletHell = ZoneService.bullets_hell.pick_random().instance()
		bullet_hell._update_bullet_hell_parameters(wave, _is_elite_wave, _is_horde_wave)
		_enemy_projectiles.add_child(bullet_hell)


func get_gold_value(entity_type: int, args: Entity.DieArgs, base_value: float, unit: Unit = null) -> float:
	var value = .get_gold_value(entity_type, args, base_value, unit)
	if entity_type == EntityType.ENEMY and RunData.crooked_has_active_calamity(RunData.CALAMITY_FAMINE):
		value *= 0.5
	return value
