extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/garbage_reputation_test.gd

const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const GarbageDropManagerScript = preload("res://scripts/gameplay/garbage_drop_manager.gd")
const GarbageReputationConfigScript = preload("res://scripts/gameplay/garbage_reputation_config.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")
const ReputationManagerScript = preload("res://scripts/gameplay/reputation_manager.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("no penalty before grace period", await _test_no_penalty_before_grace())
	failed += _assert("uncleaned garbage reduces reputation", await _test_penalty_after_grace())
	failed += _assert("more garbage increases penalty", await _test_more_garbage_stronger_penalty())
	failed += _assert("cleaning garbage stops penalty", await _test_cleaning_stops_penalty())
	failed += _assert("game time advance applies penalty", await _test_game_time_penalty())

	if failed == 0:
		print("garbage_reputation_test: ALL PASSED")
		quit(0)
	else:
		push_error("garbage_reputation_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GridService") == null:
		var grid: WarehouseGrid = GridScript.new()
		grid.name = "GridService"
		root.add_child(grid)
	if root.get_node_or_null("GameTimeManager") == null:
		var game_time: Node = GameTimeManagerScript.new()
		game_time.name = "GameTimeManager"
		root.add_child(game_time)
	if root.get_node_or_null("ReputationManager") == null:
		var reputation: Node = ReputationManagerScript.new()
		reputation.name = "ReputationManager"
		root.add_child(reputation)
	if root.get_node_or_null("GarbageDropManager") == null:
		var garbage: Node = GarbageDropManagerScript.new()
		garbage.name = "GarbageDropManager"
		root.add_child(garbage)


func _reset_scene() -> void:
	_reputation().reset_for_new_game()
	_game_time().reset_for_new_game()
	_manager().reset_for_new_game()
	_game_time().set_time(1, 500)
	await process_frame


func _manager() -> Node:
	return root.get_node("GarbageDropManager")


func _reputation() -> Node:
	return root.get_node("ReputationManager")


func _game_time() -> Node:
	return root.get_node("GameTimeManager")


func _spawn_garbage(position: Vector3 = Vector3(10.0, 0.0, 10.0)):
	return _manager().spawn_garbage_at(position)


func _advance_to_minute(minute: int) -> void:
	_game_time().set_time(1, minute)


func _test_no_penalty_before_grace() -> bool:
	await _reset_scene()
	_spawn_garbage()
	_advance_to_minute(500 + int(GarbageReputationConfigScript.GRACE_GAME_MINUTES) - 1)
	var loss: int = _manager().advance_reputation_penalty(
		GarbageReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	)
	return (
		loss == 0
		and int(_reputation().call("get_reputation")) == ReputationConfigScript.STARTING_REPUTATION
		and _manager().count_offending_garbage() == 0
	)


func _test_penalty_after_grace() -> bool:
	await _reset_scene()
	_spawn_garbage()
	_advance_to_minute(500 + int(GarbageReputationConfigScript.GRACE_GAME_MINUTES) + 2)
	var before: int = int(_reputation().call("get_reputation"))
	var loss: int = _manager().advance_reputation_penalty(
		GarbageReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	)
	return (
		_manager().count_offending_garbage() == 1
		and loss >= GarbageReputationConfigScript.REPUTATION_LOSS_PER_PIECE_PER_TICK
		and int(_reputation().call("get_reputation")) < before
	)


func _test_more_garbage_stronger_penalty() -> bool:
	await _reset_scene()
	for i in range(3):
		_spawn_garbage(Vector3(10.0 + float(i) * 0.3, 0.0, 10.0))
	_advance_to_minute(500 + int(GarbageReputationConfigScript.GRACE_GAME_MINUTES) + 2)
	var loss: int = _manager().advance_reputation_penalty(
		GarbageReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	)
	return (
		_manager().count_offending_garbage() == 3
		and loss == 3 * GarbageReputationConfigScript.REPUTATION_LOSS_PER_PIECE_PER_TICK
	)


func _test_cleaning_stops_penalty() -> bool:
	await _reset_scene()
	var garbage = _spawn_garbage()
	_advance_to_minute(500 + int(GarbageReputationConfigScript.GRACE_GAME_MINUTES) + 2)
	_manager().advance_reputation_penalty(GarbageReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES)
	var after_first: int = int(_reputation().call("get_reputation"))
	if after_first >= ReputationConfigScript.STARTING_REPUTATION:
		return false
	garbage.clean()
	await process_frame
	_advance_to_minute(520)
	var loss: int = _manager().advance_reputation_penalty(
		GarbageReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES * 2.0
	)
	return loss == 0 and int(_reputation().call("get_reputation")) == after_first


func _test_game_time_penalty() -> bool:
	await _reset_scene()
	_spawn_garbage()
	_manager().call("_bind_game_time")
	_game_time().set_running(true)
	var before: int = int(_reputation().call("get_reputation"))
	_game_time().advance_by_game_minutes(
		GarbageReputationConfigScript.GRACE_GAME_MINUTES
		+ GarbageReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	)
	await process_frame
	return int(_reputation().call("get_reputation")) < before
