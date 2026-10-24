extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = load("res://tests/bomb_upgrade_tests.gd").new().run(root)
	quit(0 if report.failures == 0 else 1)
