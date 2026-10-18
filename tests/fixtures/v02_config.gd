extends RefCounted

# Frozen setup for the original 253 checks. New play defaults live in main.tscn.
static func apply(game: MainGame) -> void:
	game.economy.starting_gold = 200
	game.economy.starting_lives = 20
	game.economy.reset()
	game.waves.waves = [preload("res://data/waves/wave_01.tres"),
		preload("res://data/waves/wave_02.tres"), preload("res://data/waves/wave_03.tres")]
	game.hud.set_wave(0, 3, false)
