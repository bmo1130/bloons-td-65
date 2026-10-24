extends "res://tests/properties_visual.gd"

func _run() -> void:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	var kinds: Array[String] = ["red", "blue", "green", "yellow", "pink", "black", "white", "zebra", "rainbow", "ceramic", "lead", "moab", "bfb", "zomg", "ddt", "bad"]
	var centers: Array[Vector2] = []
	for index in range(kinds.size()):
		var at: Vector2 = Vector2(120 + (index % 5) * 160, 220 + (index / 5) * 120)
		var balloon: BalloonState = game.balloons.spawn(load("res://data/balloons/%s.tres" % kinds[index]), 500.0, index >= 5, index >= 9, true, index >= 9)
		balloon.position = at
		balloon.record_motion(PackedVector2Array([at, at]), 0.0)
		if index < 5:
			centers.append(at)
	var custom: BalloonDefinition = (load("res://data/balloons/blue.tres") as BalloonDefinition).duplicate() as BalloonDefinition
	custom.radius = 24.0
	var large: BalloonState = game.balloons.spawn(custom)
	large.position = Vector2(440, 580)
	large.record_motion(PackedVector2Array([large.position, large.position]), 0.0)
	game.balloons.use_draw_cache = false
	game.balloons.queue_redraw()
	await _capture("balloon-cache-before-v0111")
	var reference: Image = root.get_texture().get_image()
	game.balloons.use_draw_cache = true
	game.balloons.queue_redraw()
	await _capture("balloon-cache-after-v0111")
	var cached: Image = root.get_texture().get_image()
	_check(game.balloons._plain_atlas != null and game.balloons._plain_atlas.get_size() == Vector2(1024, 1024), "single bounded 2x atlas created")
	_check(game.balloons._plain_regions.size() == 6 and not game.balloons._plain_regions.has(custom), "five basic colors and lead cached; oversized custom geometry falls back")
	var error: float = 0.0
	var pixels: int = 0
	for at in centers:
		var first: Color = reference.get_pixelv(Vector2i(at))
		var second: Color = cached.get_pixelv(Vector2i(at))
		_check(absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b) < 0.025, "cached body palette matches vector original")
		for y in range(int(at.y) - 28, int(at.y) + 36):
			for x in range(int(at.x) - 32, int(at.x) + 32):
				var a: Color = reference.get_pixel(x, y)
				var b: Color = cached.get_pixel(x, y)
				error += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				pixels += 3
	var mean_error: float = error / pixels
	_check(mean_error < 0.025, "bounded raster/antialias difference from original vector appearance")
	print("BALLOON CACHE IMAGE MEAN ABS DIFFERENCE: %.6f" % mean_error)
	for index in range(5, kinds.size()):
		var at: Vector2 = game.balloons.balloons[index].position
		_check(reference.get_pixelv(Vector2i(at)) == cached.get_pixelv(Vector2i(at)), "styled bloon/blimp overlays and fallback preserved")
	print("BALLOON CACHE VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
