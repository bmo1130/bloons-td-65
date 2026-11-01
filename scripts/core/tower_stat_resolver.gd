class_name TowerStatResolver
extends RefCounted

const FIELDS: Array[StringName] = [&"damage", &"pierce", &"fire_interval", &"attack_range",
	&"projectile_speed", &"projectile_radius", &"projectile_length", &"projectile_count",
	&"spread_degrees", &"heading_offset_degrees", &"attack_attribute", &"explosion_radius",
	&"projectile_lifetime", &"ceramic_bonus", &"fortified_bonus", &"knockback_duration",
	&"knockback_light", &"knockback_heavy", &"max_bounces", &"critical_every", &"critical_damage", &"lead_bonus", &"detects_camo", &"moab_bonus",
	&"stun_duration", &"stun_moab_duration", &"push_distance", &"push_moab_distance", &"frag_damage_bonus", &"recursive_every",
	&"flight_mode", &"flight_distance", &"curve_width", &"rehit_interval", &"chain_range", &"projectile_style"]
const INTEGER_FIELDS: Array[StringName] = [&"damage", &"pierce", &"projectile_count", &"attack_attribute",
	&"ceramic_bonus", &"fortified_bonus", &"max_bounces", &"critical_every", &"critical_damage", &"lead_bonus", &"moab_bonus", &"frag_damage_bonus", &"recursive_every", &"flight_mode", &"projectile_style"]

static func acquired(base: TowerDefinition, tiers: PackedInt32Array) -> Array[UpgradeDefinition]:
	var items: Array[UpgradeDefinition] = []
	# Canonical order is independent of the catalog's file ordering.
	for path in range(3):
		for tier in range(1, tiers[path] + 1):
			var item: UpgradeDefinition = base.upgrade_at(path, tier)
			if item != null:
				items.append(item)
	return items

static func resolve(base: TowerDefinition, tiers: PackedInt32Array) -> TowerDefinition:
	var stats: TowerDefinition = base.duplicate() as TowerDefinition
	var items: Array[UpgradeDefinition] = acquired(base, tiers)
	for field in FIELDS:
		var replacement: UpgradeDefinition
		for item in items:
			if item.replacement_values.has(field):
				replacement = item
		var added: float = 0.0
		var multiplied: float = 1.0
		for item in items:
			if replacement != null and item.path == replacement.path and item.tier <= replacement.tier:
				continue
			added += float(item.additions.get(field, 0.0))
			multiplied *= float(item.multipliers.get(field, 1.0))
		var initial: float = float(base.get(field)) if replacement == null else float(replacement.replacement_values[field])
		var value: float = (initial + added) * multiplied
		for item in items:
			if replacement != null and item.path == replacement.path and item.tier <= replacement.tier:
				continue
			if item.overrides.has(field):
				value = float(item.overrides[field])
		if field == &"detects_camo":
			stats.set(field, value > 0.5)
		elif field in INTEGER_FIELDS:
			stats.set(field, roundi(value))
		else:
			stats.set(field, value)
	for item in items:
		if item.primary_attack_pattern >= 0:
			stats.attack_pattern = item.primary_attack_pattern as TowerDefinition.AttackPattern
		if item.minimum_fire_interval > 0.0:
			stats.minimum_fire_interval = item.minimum_fire_interval
		if item.aura_profile != null:
			stats.aura_profile = item.aura_profile.duplicate(true)
		if item.secondary_attack != null:
			stats.secondary_attack = item.secondary_attack.duplicate()
			var secondary: TowerDefinition = stats.secondary_attack as TowerDefinition
			if secondary.end_explosion != null:
				secondary.end_explosion = secondary.end_explosion.duplicate()
		if item.damage_over_time != null:
			stats.damage_over_time = item.damage_over_time
			stats.dot_first_moab = item.dot_first_moab
		if item.ability != null:
			stats.ability = item.ability
			if item.ability.effect == AbilityDefinition.Effect.RADIAL_BURST:
				stats.ability = item.ability.duplicate() as AbilityDefinition
				stats.ability.attack_profile = item.ability.attack_profile.duplicate() as TowerDefinition
		if item.projectile_split != null:
			stats.projectile_split = item.projectile_split
		for interaction in item.interactions:
			var required: Array = interaction.get("requires", [0, 0, 0])
			if tiers[0] >= required[0] and tiers[1] >= required[1] and tiers[2] >= required[2]:
				for profile_name: String in interaction.get("profiles", {}):
					var profile: Resource = stats.get(profile_name) as Resource
					if profile != null:
						_apply_profile_values(profile, interaction.profiles[profile_name])
				for field: String in interaction.get("multipliers", {}):
					stats.set(field, float(stats.get(field)) * float(interaction.multipliers[field]))
				for field: String in interaction.get("overrides", {}):
					stats.set(field, interaction.overrides[field])
	# A secondary path must not hide the main path's visual identity.
	# Highest tier wins; equal tiers use canonical path/tier order as a tie break.
	var visual_tier: int = 0
	for item in items:
		if item.visual_color.a > 0.0 and item.tier >= visual_tier:
			stats.color = item.visual_color
			visual_tier = item.tier
	stats.damage = maxi(1, stats.damage)
	stats.pierce = maxi(1, stats.pierce)
	stats.fire_interval = maxf(stats.minimum_fire_interval, stats.fire_interval)
	stats.attack_range = maxf(1.0, stats.attack_range)
	stats.projectile_speed = maxf(1.0, stats.projectile_speed)
	stats.projectile_radius = maxf(0.1, stats.projectile_radius)
	stats.projectile_length = maxf(0.1, stats.projectile_length)
	stats.projectile_count = clampi(stats.projectile_count, 1, 32)
	stats.spread_degrees = clampf(stats.spread_degrees, 0.0, 360.0)
	if stats.projectile_range_multiplier > 0.0:
		stats.projectile_lifetime = stats.attack_range * stats.projectile_range_multiplier / stats.projectile_speed
	if stats.attack_pattern == TowerDefinition.AttackPattern.AREA and stats.aura_profile != null:
		var area: TowerDefinition = stats.aura_profile as TowerDefinition
		area.damage = stats.damage
		area.pierce = stats.pierce
		area.fire_interval = stats.fire_interval
		area.explosion_radius = stats.attack_range
		area.attack_attribute = stats.attack_attribute
		area.moab_bonus = stats.moab_bonus
		area.detects_camo = stats.detects_camo
	return stats

static func preview(base: TowerDefinition, tiers: PackedInt32Array, upgrade: UpgradeDefinition) -> TowerDefinition:
	var next_tiers: PackedInt32Array = tiers.duplicate()
	next_tiers[upgrade.path] = upgrade.tier
	return resolve(base, next_tiers)

static func _apply_profile_values(profile: Resource, values: Dictionary) -> void:
	for field: String in values:
		if values[field] is Dictionary and profile.get(field) is Resource:
			_apply_profile_values(profile.get(field) as Resource, values[field])
		else:
			profile.set(field, values[field])
