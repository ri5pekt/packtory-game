class_name CharacterAnimationUtils
extends RefCounted

## Shared helpers for Kenney GLB character rigs (AnimationPlayer discovery + naming).


static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := find_animation_player(child)
		if found:
			return found
	return null


static func resolve_anim_name(anim: AnimationPlayer, preferred_names: Array) -> String:
	if anim == null:
		return ""
	for anim_name in preferred_names:
		if anim.has_animation(String(anim_name)):
			return String(anim_name)
	var list := anim.get_animation_list()
	if list.is_empty():
		return ""
	return list[0]
