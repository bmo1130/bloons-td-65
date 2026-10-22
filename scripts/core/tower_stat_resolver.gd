class_name TowerStatResolver
extends RefCounted

const FIELDS: Array[StringName] = [&"damage", &"pierce", &"fire_interval", &"attack_range",
	&"projectile_speed", &"projectile_radius", &"projectile_length", &"projectile_count",
	&"spread_degrees", &"heading_offset_degrees", &"attack_attribute", &"explosion_radius",
	&"projectile_lifetime", &"ceramic_bonus", &"fortified_bonus", &"knockback_duration",
	&"knockback_light", &"knockback_heavy", &"max_bounces", &"critical_every", &"critical_damage", &"lead_bonus", &"detects_camo", &"moab_bonus"]
const INTEGER_FIELDS: Array[StringName] = [&"damage", &"pierce", &"projectile_count", &"attack_attribute",
	&"ceramic_bonus", &"fortified_bonus", &"max_bounces", &"critical_every", &"critical_damage", &"lead_bonus", &"moab_bonus"]

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
		if item.ability != null:
			stats.ability = item.ability
		if item.projectile_split != null:
			stats.projectile_split = item.projectile_split
		for interaction in item.interactions:
			var required: Array = interaction.get("requires", [0, 0, 0])
			if tiers[0] >= required[0] and tiers[1] >= required[1] and tiers[2] >= required[2]:
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
	stats.fire_interval = maxf(0.05, stats.fire_interval)
	stats.attack_range = maxf(1.0, stats.attack_range)
	stats.projectile_speed = maxf(1.0, stats.projectile_speed)
	stats.projectile_radius = maxf(0.1, stats.projectile_radius)
	stats.projectile_length = maxf(0.1, stats.projectile_length)
	stats.projectile_count = clampi(stats.projectile_count, 1, 32)
	stats.spread_degrees = clampf(stats.spread_degrees, 0.0, 360.0)
	return stats

static func preview(base: TowerDefinition, tiers: PackedInt32Array, upgrade: UpgradeDefinition) -> TowerDefinition:
	var next_tiers: PackedInt32Array = tiers.duplicate()
	next_tiers[upgrade.path] = upgrade.tier
	return resolve(base, next_tiers)
