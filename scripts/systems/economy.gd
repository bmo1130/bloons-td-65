class_name GameEconomy
extends Node

signal changed(gold: int, lives: int)
signal defeated

@export var starting_gold: int = 200
@export var starting_lives: int = 20
var gold: int = 0
var lives: int = 0

func reset() -> void:
	gold = starting_gold
	lives = starting_lives
	changed.emit(gold, lives)

func try_spend(amount: int) -> bool:
	if amount <= 0 or gold < amount or lives <= 0:
		return false
	gold -= amount
	changed.emit(gold, lives)
	return true

func earn(amount: int) -> void:
	if amount > 0 and lives > 0:
		gold += amount
		changed.emit(gold, lives)

func lose_lives(amount: int) -> void:
	if amount <= 0 or lives <= 0:
		return
	lives = maxi(0, lives - amount)
	changed.emit(gold, lives)
	if lives == 0:
		defeated.emit()
