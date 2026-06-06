extends SceneTree

## Run with: godot --headless --path . --script res://scripts/test/interactable_raycast_test.gd

const InteractableRaycastScript = preload("res://scripts/shared/interactable_raycast.gd")
const DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")


func _init() -> void:
	var failed := 0
	failed += _assert("delivery box beats outbound van", _test_box_priority_over_van())
	failed += _assert("equipment group beats outbound van", _test_equipment_priority_over_van())
	failed += _assert("closest wins equal priority", _test_distance_tiebreak())

	if failed == 0:
		print("interactable_raycast_test: ALL PASSED")
		quit(0)
	else:
		push_error("interactable_raycast_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _test_box_priority_over_van() -> bool:
	var box: Node = DeliveryBoxScript.new()
	var van := Node3D.new()
	van.add_to_group("outbound_delivery_vehicles")
	var hits := [
		{"node": van, "distance": 1.0, "priority": InteractableRaycastScript.interactable_priority(van)},
		{"node": box, "distance": 2.0, "priority": InteractableRaycastScript.interactable_priority(box)},
	]
	return InteractableRaycastScript._select_best_hit(hits) == box


func _test_equipment_priority_over_van() -> bool:
	var equip := Node3D.new()
	equip.add_to_group("equipment_delivery_boxes")
	var van := Node3D.new()
	van.add_to_group("outbound_delivery_vehicles")
	var hits := [
		{"node": van, "distance": 0.5, "priority": InteractableRaycastScript.interactable_priority(van)},
		{"node": equip, "distance": 3.0, "priority": InteractableRaycastScript.interactable_priority(equip)},
	]
	return InteractableRaycastScript._select_best_hit(hits) == equip


func _test_distance_tiebreak() -> bool:
	var near := Node3D.new()
	near.add_to_group("floor_garbage")
	var far := Node3D.new()
	far.add_to_group("floor_garbage")
	var priority := InteractableRaycastScript.interactable_priority(near)
	var hits := [
		{"node": far, "distance": 5.0, "priority": priority},
		{"node": near, "distance": 1.0, "priority": priority},
	]
	return InteractableRaycastScript._select_best_hit(hits) == near
