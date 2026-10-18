extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var suite: RefCounted = load("res://tests/tier5_tests.gd").new()
	var report: Dictionary = suite.run(root)
	quit(0 if report.failures == 0 else 1)
