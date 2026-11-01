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
		_update_auxiliary(tower, stats, delta)
		tower.cooldown -= delta
		if tower.cooldown > 0.0:
			continue
		if stats.attack_pattern == TowerDefinition.AttackPattern.AREA:
			_update_primary_area(tower, stats, delta)
			continue
		if stats.attack_pattern == TowerDefinition.AttackPattern.RADIAL:
			_update_radial(tower, stats, delta)
			continue
		var target: BalloonState = _first_in_range(tower)
		if target == null:
			tower.cooldown = 0.1
			continue
		tower.direction = tower.position.direction_to(target.position)
		# New flight modes use a half-open step interval: a shot due exactly at
		# the end belongs to the next step, independent of floating-point sign.
		while (tower.cooldown < -0.000000001 if stats.flight_mode != TowerDefinition.Flight.STRAIGHT else tower.cooldown <= 0.0):
			var continuous_reload: bool = tower.transformed_stats != null or stats.flight_mode != TowerDefinition.Flight.STRAIGHT
			var critical: bool = false
			if stats.critical_every > 0:
				critical = (tower.critical_counter + 1) % stats.critical_every == 0
			var fraction: float = clampf((delta + tower.cooldown) / delta, 0.0, 1.0) if continuous_reload else 0.0
			var recursive: bool = stats.recursive_every > 0 and (tower.attack_counter + 1) % stats.recursive_every == 0
			var launched: int = projectile_system.fire_volley(tower.position + tower.direction * 22.0, target, stats, tower.id, critical, fraction, recursive, tower.position)
			if launched > 0:
				tower.attack_counter += 1
			if launched > 0 and stats.critical_every > 0:
				tower.critical_counter += 1
				if critical:
					tower.crit_flash = 0.4
			if not continuous_reload:
				tower.cooldown = stats.fire_interval
				break
			tower.cooldown += stats.fire_interval
	queue_redraw()

func _first_in_range(tower: TowerState) -> BalloonState:
	var first: BalloonState = null
	var stats: TowerDefinition = tower.combat_definition()
	var bounds: Rect2 = Rect2(tower.position, Vector2.ZERO).grow(stats.attack_range)
	for balloon in balloon_system.candidates_in_rect(bounds):
		if balloon_system.find(balloon.id) == null or balloon.exit_time <= 1.0:
			continue
		if not combat.can_target(balloon, stats):
			continue
		# Existing small-bloon center acquisition stays unchanged. Blimps expose
		# their circular hitbox at the range boundary, also indexed by the grid.
		var reach: float = stats.attack_range + (balloon.definition.radius if balloon.definition.moab_class else 0.0)
		if tower.position.distance_squared_to(balloon.position) <= reach * reach:
			if first == null or _prefer_target(balloon, first, tower):
				first = balloon
	return first

func _prefer_target(candidate: BalloonState, current: BalloonState, tower: TowerState) -> bool:
	match tower.target_mode:
		TowerState.TargetMode.LAST:
			if candidate.distance != current.distance:
				return candidate.distance < current.distance
		TowerState.TargetMode.CLOSE:
			var a: float = tower.position.distance_squared_to(candidate.position)
			var b: float = tower.position.distance_squared_to(current.position)
			if a != b:
				return a < b
		TowerState.TargetMode.STRONG:
			var a: int = candidate.definition.strength_rank
			var b: int = current.definition.strength_rank
			a = candidate.definition.total_rbe() if a == 0 else a
			b = current.definition.total_rbe() if b == 0 else b
			if a != b:
				return a > b
			if candidate.fortified != current.fortified:
				return candidate.fortified
			if candidate.shell_hp != current.shell_hp:
				return candidate.shell_hp > current.shell_hp
	# First is also the deterministic tie-break for Close/Strong.
	if tower.target_mode != TowerState.TargetMode.LAST and candidate.distance != current.distance:
		return candidate.distance > current.distance
	return candidate.id < current.id

func _draw() -> void:
	var measuring: bool = projectile_system != null and projectile_system.profile_updates
	var started: int = Time.get_ticks_usec() if measuring else 0
	for tower in towers:
		var stats: TowerDefinition = tower.combat_definition()
		if tower == selected:
			draw_circle(tower.position, stats.attack_range, Color(stats.color, 0.05))
			draw_arc(tower.position, stats.attack_range, 0, TAU, 64, Color(stats.color, 0.5), 1.5, true)
			draw_arc(tower.position, 25.0, 0, TAU, 32, Color("ffffff"), 2.0, true)
		var aura: TowerDefinition = stats.aura_profile as TowerDefinition
		if aura != null and stats.attack_pattern != TowerDefinition.AttackPattern.AREA:
			draw_arc(tower.position, aura.explosion_radius, 0, TAU, 48, Color(stats.color, 0.25), 1.0, true)
			for index in range(3):
				var phase: float = tower.orbit_phase + index * TAU / 3.0
				var at: Vector2 = tower.position + Vector2.from_angle(phase) * aura.explosion_radius
				draw_line(at - Vector2.from_angle(phase * 3.0) * 13, at + Vector2.from_angle(phase * 3.0) * 13, Color("e4f5fa"), 5, true)
				draw_line(at - Vector2.from_angle(phase * 3.0).orthogonal() * 13, at + Vector2.from_angle(phase * 3.0).orthogonal() * 13, Color("ffd477"), 4, true)
		if stats.attack_pattern != TowerDefinition.AttackPattern.AIMED:
			_draw_radial_tower(tower.position, stats)
			if stats.attack_pattern == TowerDefinition.AttackPattern.AREA:
				var pulse: float = sin(tower.orbit_phase * 4) * 0.5 + 0.5
				draw_circle(tower.position, stats.attack_range, Color(1.0,0.25,0.03,0.035))
				draw_arc(tower.position, stats.attack_range*(0.94+0.04*pulse),0,TAU,64,Color(1.0,0.36,0.07,0.55),4,true)
				for flame in range(8):
					var axis: Vector2 = Vector2.from_angle(tower.orbit_phase + TAU*flame/8)
					draw_line(tower.position+axis*8,tower.position+axis*(24+5*pulse),Color("ffc54f"),5,true)
		else:
			_draw_tower(tower.position, tower.direction, tower.stats.color)
		if tower.transformed_stats != null:
			draw_colored_polygon(PackedVector2Array([tower.position + Vector2(-16, -12), tower.position + Vector2(-28, 22), tower.position + Vector2(16, 15)]), Color("e46570"))
			_draw_tower(tower.position, tower.direction, stats.color)
		for path in range(3):
			for tier in range(tower.tiers[path]):
				var marker: Vector2 = tower.position + Vector2((tier - 1) * 8, 12 + path * 5)
				var upgrade: UpgradeDefinition = tower.definition.upgrade_at(path, tier + 1)
				draw_circle(marker, 2.5, upgrade.visual_color if upgrade != null else Color.WHITE)
		if stats.attack_pattern != TowerDefinition.AttackPattern.AIMED:
			pass # Fixed ports were drawn above; never draw an aimed barrel.
		elif stats.projectile_count > 1:
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
		if preview_definition.attack_pattern == TowerDefinition.AttackPattern.RADIAL:
			_draw_radial_tower(preview_position, preview_definition, Color(1,1,1,0.75))
		else:
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

func _update_auxiliary(tower: TowerState, stats: TowerDefinition, delta: float) -> void:
	var aura: TowerDefinition = stats.aura_profile as TowerDefinition
	if aura != null:
		tower.orbit_phase = fmod(tower.orbit_phase + delta * 2.5, TAU)
		if stats.attack_pattern == TowerDefinition.AttackPattern.AREA:
			aura = null
	if aura != null:
		tower.aura_cooldown -= delta
		while tower.aura_cooldown < -0.000000001:
			projectile_system.queue_area(tower.position, aura, tower.id, clampf((delta + tower.aura_cooldown) / delta, 0.0, 1.0))
			tower.aura_cooldown += aura.fire_interval
	var secondary: TowerDefinition = stats.secondary_attack as TowerDefinition
	if secondary == null:
		return
	tower.secondary_cooldown -= delta
	if tower.secondary_cooldown >= -0.000000001:
		return
	var target: BalloonState
	var range_limit: float = secondary.attack_range if secondary.attack_range > 0.0 else stats.attack_range
	for balloon in balloon_system.candidates_in_rect(Rect2(tower.position, Vector2.ZERO).grow(range_limit)):
		if balloon_system.find(balloon.id) == null or balloon.exit_time <= 1.0 or not combat.can_target(balloon, secondary):
			continue
		var reach: float = range_limit + balloon.definition.radius
		if tower.position.distance_squared_to(balloon.position) <= reach * reach and (target == null or _prefer_target(balloon, target, tower)):
			target = balloon
	if target == null:
		tower.secondary_cooldown = 0.0
		return
	while tower.secondary_cooldown < -0.000000001:
		var shot: ProjectileState = projectile_system.launch(tower.position, tower.position.direction_to(target.position), secondary, tower.id, false, -1.0, tower.position)
		if shot != null:
			if battle_stats != null and battle_stats.enabled and tower.combat_stats != null:
				tower.combat_stats.secondary_projectiles += 1
			shot.target_id = target.id
			shot.spawn_fraction = clampf((delta + tower.secondary_cooldown) / delta, 0.0, 1.0)
		tower.secondary_cooldown += secondary.fire_interval

func _update_radial(tower: TowerState, stats: TowerDefinition, delta: float) -> void:
	if not _radial_occupied(tower, stats):
		tower.cooldown = 0.0
		return
	while tower.cooldown < -0.000000001:
		var fraction: float = clampf((delta + tower.cooldown) / delta, 0.0, 1.0)
		if projectile_system.fire_volley(tower.position, null, stats, tower.id, false, fraction) > 0:
			tower.attack_counter += 1
		tower.cooldown += stats.fire_interval

func _draw_radial_tower(at: Vector2, stats: TowerDefinition, tint: Color = Color.WHITE) -> void:
	draw_circle(at + Vector2(2,5), stats.radius + 2, Color(0.02,0.07,0.09,0.4))
	draw_circle(at, stats.radius + 1, Color("152c32") * tint)
	draw_circle(at, stats.radius - 2, stats.color * tint)
	var ports: int = 8 if stats.attack_pattern == TowerDefinition.AttackPattern.AREA else stats.projectile_count
	for index in range(ports):
		var axis: Vector2 = Vector2.from_angle(deg_to_rad(stats.heading_offset_degrees) + TAU * index / ports)
		draw_line(at + axis * 12, at + axis * 19, Color("16262c") * tint, 5, true)
		draw_line(at + axis * 16, at + axis * 20, Color("e8d7c2") * tint, 2, true)
	draw_circle(at, 9, Color("773a45") * tint)
	if stats.projectile_style == TowerDefinition.ProjectileStyle.BLADE:
		draw_circle(at, 6, Color("d3e8f5") * tint)
	elif stats.attack_attribute == AttackSpec.Attribute.NORMAL:
		draw_circle(at, 5, Color("ffc759") * tint)

func _radial_occupied(tower: TowerState, stats: TowerDefinition) -> bool:
	for balloon in balloon_system.candidates_in_rect(Rect2(tower.position, Vector2.ZERO).grow(stats.attack_range)):
		if balloon_system.find(balloon.id) == null or balloon.exit_time <= 1.0 or not combat.can_target(balloon, stats):
			continue
		var reach: float = stats.attack_range + (balloon.definition.radius if balloon.definition.moab_class else 0.0)
		if tower.position.distance_squared_to(balloon.position) <= reach * reach:
			return true
	return false

func _update_primary_area(tower: TowerState, stats: TowerDefinition, delta: float) -> void:
	if not _radial_occupied(tower, stats):
		tower.cooldown = 0.0
		return
	while tower.cooldown < -0.000000001:
		projectile_system.queue_area(tower.position, stats.aura_profile as TowerDefinition, tower.id, clampf((delta+tower.cooldown)/delta,0.0,1.0))
		tower.attack_counter += 1
		if battle_stats != null:
			battle_stats.record_volley(tower.id)
		tower.cooldown += stats.fire_interval
