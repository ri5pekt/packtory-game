class_name CustomerStatus
extends RefCounted

## Reusable queue status kinds for customer head indicators.

enum Kind {
	NONE,
	WAITING,
	ORDER,
	HAPPY,
	ANGRY,
	IMPATIENT,
	READY_TO_LEAVE,
}

const KIND_TO_ID := {
	Kind.NONE: "",
	Kind.WAITING: "waiting",
	Kind.HAPPY: "happy",
	Kind.ANGRY: "angry",
	Kind.IMPATIENT: "impatient",
	Kind.READY_TO_LEAVE: "ready_to_leave",
}


static func is_visible(kind: Kind) -> bool:
	return kind != Kind.NONE


static func id_for(kind: Kind) -> String:
	return KIND_TO_ID.get(kind, "")


static func display_name(kind: Kind) -> String:
	match kind:
		Kind.WAITING:
			return "Waiting"
		Kind.ORDER:
			return "Order"
		Kind.HAPPY:
			return "Happy"
		Kind.ANGRY:
			return "Angry"
		Kind.IMPATIENT:
			return "Impatient"
		Kind.READY_TO_LEAVE:
			return "Ready To Leave"
		_:
			return ""


static func icon_for(kind: Kind) -> Texture2D:
	if kind == Kind.ORDER:
		return IconRegistry.get_icon("package")
	return IconRegistry.status_icon(id_for(kind))
