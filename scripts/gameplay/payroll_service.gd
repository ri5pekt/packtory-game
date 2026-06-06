class_name PayrollService
extends RefCounted

## Collects daily salary obligations from workers in the scene.


static func collect_payroll_entries(context) -> Array:
	var entries: Array = []
	var tree: SceneTree = null
	if context is SceneTree:
		tree = context
	elif context is Node:
		tree = context.get_tree()
	if tree == null:
		return entries
	for worker in tree.get_nodes_in_group("workers"):
		if worker == null or not worker.has_method("get_daily_salary"):
			continue
		var salary := int(worker.get_daily_salary())
		if salary <= 0:
			continue
		var entry := {
			"worker_id": String(worker.get_worker_id()) if worker.has_method("get_worker_id") else "",
			"display_name": String(worker.get_display_name()) if worker.has_method("get_display_name") else "Worker",
			"daily_salary": salary,
		}
		if worker.has_method("get_specialization"):
			entry["specialization"] = String(worker.get_specialization())
		entries.append(entry)
	return entries


static func total_payroll_amount(entries: Array) -> int:
	var total := 0
	for entry in entries:
		if entry is Dictionary:
			total += int(entry.get("daily_salary", 0))
	return total
