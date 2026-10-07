extends "res://tests/run_v03_tests.gd"

func run() -> void:
	bar_service_checks()
	await bar_ui_checks()
	print("BAR SERVICE SMOKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
