class_name IconRegistry
extends RefCounted

## Loads 2D UI icons for context-menu actions and product ids.

const ICON_DIR := "res://assets/ui/icons/"

static var _cache: Dictionary = {}


static func has_icon(id: String) -> bool:
	return ResourceLoader.exists(_path_for(id))


static func get_icon(id: String) -> Texture2D:
	if id.is_empty():
		return null
	if id == "edit_layout":
		return _edit_layout_icon()
	if _cache.has(id):
		return _cache[id]
	var path := _path_for(id)
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_cache[id] = tex
	return tex


static func action_icon(action_id: String) -> Texture2D:
	if action_id == "clean":
		return _clean_icon()
	return get_icon(action_id)


static func product_icon(product_id: String) -> Texture2D:
	var tex := get_icon(product_id)
	if tex != null:
		return tex
	# Procedural fallbacks for products without a PNG asset
	match product_id:
		"smart_watch":
			return _status_fallback("__smart_watch__", _draw_smart_watch_icon)
	return null


static func truck_icon() -> Texture2D:
	return _status_fallback("__truck_icon__", _draw_truck_icon)


static func waiting_icon() -> Texture2D:
	return status_icon("waiting")


static func status_icon(status_id: String) -> Texture2D:
	match status_id:
		"waiting":
			return _status_fallback("__waiting_icon_v2__", _draw_waiting_icon)
		"happy":
			if has_icon("happy"):
				return get_icon("happy")
			return _status_fallback("__happy_fallback__", _draw_happy_icon)
		"angry":
			if has_icon("angry"):
				return get_icon("angry")
			return _status_fallback("__angry_fallback__", _draw_angry_icon)
		"impatient":
			if has_icon("impatient"):
				return get_icon("impatient")
			return _status_fallback("__impatient_fallback__", _draw_impatient_icon)
		"ready_to_leave":
			if has_icon("ready_to_leave"):
				return get_icon("ready_to_leave")
			return _status_fallback("__ready_to_leave_fallback__", _draw_ready_to_leave_icon)
		_:
			return null


static func _status_fallback(cache_key: String, draw_callable: Callable) -> Texture2D:
	if _cache.has(cache_key):
		return _cache[cache_key]
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	draw_callable.call(img, S)
	var tex := ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex


static func _draw_waiting_icon(img: Image, size: int) -> void:
	var cx := size / 2
	var ring := Color(0.34, 0.62, 0.92)
	var face := Color(0.94, 0.97, 1.0)
	var hand := Color(0.20, 0.38, 0.66)
	var tick := Color(0.58, 0.74, 0.94)
	for y in range(12, 52):
		for x in range(12, 52):
			var dx := float(x - cx)
			var dy := float(y - cx)
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= 19.0 and dist >= 17.0:
				img.set_pixel(x, y, ring)
			elif dist < 17.0:
				img.set_pixel(x, y, face)
	for i in range(12):
		var angle := -PI * 0.5 + TAU * float(i) / 12.0
		var inner := 11.0
		var outer := 14.0
		var x0 := cx + int(cos(angle) * inner)
		var y0 := cx + int(sin(angle) * inner)
		var x1 := cx + int(cos(angle) * outer)
		var y1 := cx + int(sin(angle) * outer)
		_draw_line(img, Vector2i(x0, y0), Vector2i(x1, y1), tick)
	# Hour hand (short, left)
	_draw_line(img, Vector2i(cx, cx), Vector2i(cx - 5, cx - 4), hand)
	# Minute hand (long, right)
	_draw_line(img, Vector2i(cx, cx), Vector2i(cx + 2, cx - 9), hand)
	img.set_pixel(cx, cx, hand)


static func _draw_line(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx + dy
	var x := from.x
	var y := from.y
	while true:
		if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
			img.set_pixel(x, y, color)
		if x == to.x and y == to.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


static func _draw_happy_icon(img: Image, size: int) -> void:
	var cx := size / 2
	var face := Color(0.98, 0.84, 0.28)
	var stroke := Color(0.45, 0.34, 0.08)
	for y in range(10, 54):
		for x in range(10, 54):
			var dx := float(x - cx)
			var dy := float(y - 32)
			if dx * dx + dy * dy <= 20.0 * 20.0:
				img.set_pixel(x, y, face)
	for x in range(20, 45):
		img.set_pixel(x, 10, stroke)
		img.set_pixel(x, 53, stroke)
	for y in range(10, 54):
		img.set_pixel(10, y, stroke)
		img.set_pixel(53, y, stroke)
	for eye_x in [22, 41]:
		for y in range(24, 30):
			for x in range(eye_x, eye_x + 5):
				img.set_pixel(x, y, stroke)
	for x in range(22, 44):
		var t := float(x - 22) / 21.0
		var smile_y := 40 + int(sin(t * PI) * 5.0)
		img.set_pixel(x, smile_y, stroke)
		img.set_pixel(x, smile_y + 1, stroke)


static func _draw_angry_icon(img: Image, size: int) -> void:
	var cx := size / 2
	var face := Color(0.95, 0.42, 0.36)
	var stroke := Color(0.45, 0.12, 0.10)
	for y in range(10, 54):
		for x in range(10, 54):
			var dx := float(x - cx)
			var dy := float(y - 32)
			if dx * dx + dy * dy <= 20.0 * 20.0:
				img.set_pixel(x, y, face)
	for brow_y in range(22, 25):
		for x in range(18, 28):
			img.set_pixel(x, brow_y + (x - 18) / 3, stroke)
		for x in range(36, 46):
			img.set_pixel(x, brow_y + (45 - x) / 3, stroke)
	for eye_x in [22, 41]:
		for y in range(28, 33):
			for x in range(eye_x, eye_x + 5):
				img.set_pixel(x, y, stroke)
	for x in range(24, 42):
		img.set_pixel(x, 44, stroke)
		img.set_pixel(x, 45, stroke)


static func _draw_impatient_icon(img: Image, size: int) -> void:
	var frame := Color(0.36, 0.52, 0.78)
	var hand := Color(0.94, 0.76, 0.32)
	var cx := size / 2
	for y in range(12, 52):
		for x in range(18, 46):
			if absf(float(x - cx)) <= 12.0:
				img.set_pixel(x, y, frame)
	for y in range(30, 52):
		for x in range(cx - 2, cx + 3):
			img.set_pixel(x, y, hand)
	for y in range(18, 24):
		for x in range(cx - 8, cx + 9):
			img.set_pixel(x, y, frame)
	for tick_x in [cx - 6, cx, cx + 6]:
		for y in range(20, 24):
			img.set_pixel(tick_x, y, Color.WHITE)


static func _draw_ready_to_leave_icon(img: Image, size: int) -> void:
	var box := Color(0.82, 0.58, 0.28)
	var arrow := Color(0.28, 0.72, 0.48)
	for y in range(24, 46):
		for x in range(20, 44):
			img.set_pixel(x, y, box)
	for y in range(28, 42):
		for x in range(24, 40):
			img.set_pixel(x, y, box.lightened(0.08))
	for y in range(18, 28):
		for x in range(28, 36):
			img.set_pixel(x, y, arrow)
	for x in range(30, 46):
		var t := float(x - 30) / 15.0
		var y := 30 - int(t * 6.0)
		img.set_pixel(x, y, arrow)
		img.set_pixel(x, y + 1, arrow)


static func _edit_layout_icon() -> Texture2D:
	return _status_fallback("__edit_layout_icon__", _draw_edit_layout_icon)


static func _draw_edit_layout_icon(img: Image, size: int) -> void:
	var tile := Color(0.34, 0.62, 0.92)
	var border := Color(0.18, 0.34, 0.52)
	var arrow := Color(0.94, 0.97, 1.0)
	for origin in [Vector2i(14, 14), Vector2i(34, 14), Vector2i(14, 34), Vector2i(34, 34)]:
		for y in range(origin.y, origin.y + 14):
			for x in range(origin.x, origin.x + 14):
				var edge: bool = (
					x == origin.x
					or x == origin.x + 13
					or y == origin.y
					or y == origin.y + 13
				)
				img.set_pixel(x, y, border if edge else tile)
	for point in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 31), Vector2i(31, 31)]:
		img.set_pixel(point.x, point.y, arrow)
	for x in range(36, 50):
		img.set_pixel(x, 31, arrow)
		img.set_pixel(x, 32, arrow)
	img.set_pixel(49, 30, arrow)
	img.set_pixel(49, 33, arrow)
	img.set_pixel(48, 29, arrow)
	img.set_pixel(48, 34, arrow)


static func _clean_icon() -> Texture2D:
	if has_icon("clean"):
		return get_icon("clean")
	return _status_fallback("__clean_fallback__", _draw_clean_icon)


static func _draw_clean_icon(img: Image, size: int) -> void:
	var handle := Color(0.62, 0.44, 0.24)
	var bristle := Color(0.42, 0.78, 0.52)
	var sparkle := Color(0.88, 0.95, 1.0)
	for y in range(18, 46):
		for x in range(30, 36):
			img.set_pixel(x, y, handle)
	for y in range(12, 22):
		for x in range(20, 44):
			if (x + y) % 3 == 0:
				img.set_pixel(x, y, bristle)
	for point in [Vector2i(18, 16), Vector2i(46, 20), Vector2i(40, 12)]:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				img.set_pixel(point.x + dx, point.y + dy, sparkle)


static func _draw_smart_watch_icon(img: Image, size: int) -> void:
	var band := Color(0.28, 0.60, 0.72)
	var body := Color(0.22, 0.48, 0.62)
	var screen := Color(0.68, 0.92, 1.0)
	var cx := size / 2
	# Band top and bottom
	for y in range(8, 18):
		for x in range(cx - 6, cx + 7):
			img.set_pixel(x, y, band)
	for y in range(46, 56):
		for x in range(cx - 6, cx + 7):
			img.set_pixel(x, y, band)
	# Watch body (rounded rect)
	for y in range(16, 48):
		for x in range(cx - 12, cx + 13):
			var dist_x := absf(float(x - cx)) - 8.0
			var dist_y := absf(float(y - 32)) - 12.0
			var corner := maxf(dist_x, 0.0) * maxf(dist_x, 0.0) + maxf(dist_y, 0.0) * maxf(dist_y, 0.0)
			if corner < 16.0:
				img.set_pixel(x, y, body)
	# Screen
	for y in range(22, 42):
		for x in range(cx - 8, cx + 9):
			img.set_pixel(x, y, screen)
	# Clock hands
	_draw_line(img, Vector2i(cx, 32), Vector2i(cx, 26), band)
	_draw_line(img, Vector2i(cx, 32), Vector2i(cx + 4, 35), band)
	img.set_pixel(cx, 32, body)


static func _draw_truck_icon(img: Image, size: int) -> void:
	var body_col := Color(0.28, 0.68, 0.46)
	var cab_col := Color(0.22, 0.56, 0.38)
	var wheel := Color(0.18, 0.18, 0.22)
	var window := Color(0.72, 0.90, 1.0)
	# Cargo box
	for y in range(20, 46):
		for x in range(8, 42):
			img.set_pixel(x, y, body_col)
	# Cab
	for y in range(26, 46):
		for x in range(40, 58):
			img.set_pixel(x, y, cab_col)
	# Cab window
	for y in range(29, 38):
		for x in range(43, 55):
			img.set_pixel(x, y, window)
	# Wheels
	for center in [Vector2i(18, 47), Vector2i(48, 47)]:
		for y in range(center.y - 5, center.y + 6):
			for x in range(center.x - 5, center.x + 6):
				var d: int = (x - center.x) * (x - center.x) + (y - center.y) * (y - center.y)
				if d <= 25:
					img.set_pixel(x, y, wheel)


static func _path_for(id: String) -> String:
	return ICON_DIR + id + ".png"
