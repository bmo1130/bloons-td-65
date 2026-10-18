class_name TowerSystem
extends Node2D

var balloon_system: BalloonSystem
var projectile_system: ProjectileSystem
var combat: CombatSystem
var battle_stats: BattleStatistics
var abilities: AbilitySystem
var tier5_registry: Tier5Registry = Tier5Registry.new()
var draw_usec: int = 0
var _next_id: int = 1
var towers: Array[TowerState] = []
var selected: TowerState
var preview_visible: bool = false
var preview_valid: bool = false
var preview_position: Vector2
var preview_definition: TowerDefinition

func has_space(at: Vector2, radius: float) -> bool:
	for tower in towers:
		if at.distance_to(tower.position) < radius + tower.definition.radius + 8.0:
			return false
	return true

func add_tower(at: Vector2, definition: TowerDefinition) -> void:
	var tower: TowerState = TowerState.new(definition, at)
	tower.id = _next_id
	_next_id += 1
	if battle_stats != null:
		tower.combat_stats = battle_stats.register(tower.id, definition)
	towers.append(tower)
	queue_redraw()

func tower_at(at: Vector2) -> TowerState:
	for tower in towers:
		if at.distance_squared_to(tower.position) <= tower.definition.radius * tower.definition.radius:
			return tower
	return null

func find(id: int) -> TowerState:
	for tower in towers:
		if tower.id == id:
			return tower
	return null

func remove_tower(tower: TowerState) -> void:
	if not towers.has(tower):
		return
	if abilities != null:
		abilities.remove_tower(tower.id)
	tier5_registry.release(tower.id)
	if selected == tower:
		selected = null
	tower.transformed_stats = null
	towers.erase(tower)
	queue_redraw()

func update(delta: float) -> void:
	for tower in towers:
		tower.crit_flash = maxf(0.0, tower.crit_flash - delta)
		var stats: TowerDefinition = tower.combat_definition()
		tower.cooldown -= delta
		if tower.cooldown > 0.0:
			continue
		var target: BalloonState = _first_in_range(tower)
		if target == null:
			tower.cooldown = 0.1
			continue
		tower.direction = tower.position.direction_to(target.position)
		while tower.cooldown <= 0.0:
			var critical: bool = false
			if stats.critical_every > 0:
				critical = (tower.critical_counter + 1) % stats.critical_every == 0
			var fraction: float = clampf((delta + tower.cooldown) / delta, 0.0, 1.0) if tower.transformed_stats != null else 0.0
			var launched: int = projectile_system.fire_volley(tower.position + tower.direction * 22.0, target, stats, tower.id, critical, fraction)
			if launched > 0 and stats.critical_every > 0:
				tower.critical_counter += 1
				if critical:
					tower.crit_flash = 0.4
			if tower.transformed_stats == null:
				tower.cooldown = stats.fire_interval
				break
			tower.cooldown += stats.fire_interval
	queue_redraw()

func _first_in_range(tower: TowerState) -> BalloonState:
	var first: BalloonState = null
	var stats: TowerDefinition = tower.combat_definition()
	var range_squared: float = stats.attack_range * stats.attack_range
	var bounds: Rect2 = Rect2(tower.position, Vector2.ZERO).grow(stats.attack_range)
	for balloon in balloon_system.candidates_in_rect(bounds):
		if balloon_system.find(balloon.id) == null or balloon.exit_time <= 1.0:
			continue
		if not combat.can_attack(balloon, stats.attack_attribute, stats.detects_camo):
			continue
		if tower.position.distance_squared_to(balloon.position) <= range_squared:
			if first == null or balloon.distance > first.distance or (
				balloon.distance == first.distance and balloon.id < first.id):
				first = balloon
	return first

func _draw() -> void:
	var measuring: bool = projectile_system != null and projectile_system.profile_updates
	var started: int = Time.get_ticks_usec() if measuring else 0
	for tower in towers:
		var stats: TowerDefinition = tower.combat_definition()
		if tower == selected:
			draw_circle(tower.position, stats.attack_range, Color(stats.color, 0.05))
			draw_arc(tower.position, stats.attack_range, 0, TAU, 64, Color(stats.color, 0.5), 1.5, true)
			draw_arc(tower.position, 25.0, 0, TAU, 32, Color("ffffff"), 2.0, true)
		_draw_tower(tower.position, tower.direction, tower.stats.color)
		if tower.transformed_stats != null:
			draw_colored_polygon(PackedVector2Array([tower.position + Vector2(-16, -12), tower.position + Vector2(-28, 22), tower.position + Vector2(16, 15)]), Color("e46570"))
			_draw_tower(tower.position, tower.direction, stats.color)
		for path in range(3):
			for tier in range(tower.tiers[path]):
				var marker: Vector2 = tower.position + Vector2((tier - 1) * 8, 12 + path * 5)
				var upgrade: UpgradeDefinition = tower.definition.upgrade_at(path, tier + 1)
				draw_circle(marker, 2.5, upgrade.visual_color if upgrade != null else Color.WHITE)
		if stats.projectile_count > 1:
			for angle in [-12.0, 12.0]:
				draw_line(tower.position, tower.position + tower.direction.rotated(deg_to_rad(angle)) * 25, Color("fff0ce"), 3.0, true)
		elif stats.projectile_radius > 3.0:
			draw_line(tower.position, tower.position + tower.direction * 32, Color("fff0ce"), 7.0, true)
		elif stats.damage > 1:
			draw_line(tower.position, tower.position + tower.direction * 36, Color("fff0ce"), 3.0, true)
		if tower.definition.explosion_radius > 0.0:
			draw_circle(tower.position, 6.0, Color("f7b85f"))
	# Labels render after every tower so a nearby tower cannot cover CRIT text.
	for tower in towers:
		if tower.crit_flash > 0.0:
			draw_rect(Rect2(tower.position + Vector2(-22, -48), Vector2(50, 22)), Color("182d32"))
			draw_string(ThemeDB.fallback_font, tower.position + Vector2(-20, -30), "CRIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffdb7a"))
	if preview_visible and preview_definition != null:
		var color: Color = preview_definition.color if preview_valid else Color("f67878")
		draw_circle(preview_position, preview_definition.attack_range, Color(color, 0.08))
		draw_arc(preview_position, preview_definition.attack_range, 0, TAU, 64, Color(color, 0.5), 1.5, true)
		if preview_definition.explosion_radius > 0.0:
			draw_arc(preview_position, preview_definition.explosion_radius, 0, TAU, 48, Color(color, 0.4), 1.0, true)
		_draw_tower(preview_position, Vector2.UP, Color(color, 0.75))
	if measuring:
		draw_usec += Time.get_ticks_usec() - started

func _draw_tower(at: Vector2, direction: Vector2, color: Color) -> void:
	draw_circle(at + Vector2(2, 5), 22.0, Color(0.02, 0.07, 0.09, 0.4))
	draw_circle(at, 21.0, Color("152c32"))
	draw_circle(at, 17.0, color)
	draw_arc(at, 17.0, 0, TAU, 32, Color("d1fff0"), 1.5, true)
	draw_line(at, at + direction * 28.0, Color("152c32"), 10.0, true)
	draw_line(at + direction * 12.0, at + direction * 27.0, Color("e5fff4"), 4.0, true)
	draw_circle(at, 7.0, Color("274b4f"))
