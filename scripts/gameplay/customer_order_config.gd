class_name CustomerOrderConfig
extends RefCounted

## In-person order complexity — early days favor small, simple baskets.

const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")

const LATE_DAY := 10

# Distinct product lines at day 1 (percent, sum = 100).
const DAY1_ONE_PRODUCT_PCT := 82
const DAY1_TWO_PRODUCTS_PCT := 15
const DAY1_THREE_PLUS_PCT := 3

# Distinct product lines by late game (percent, sum = 100).
const LATE_ONE_PRODUCT_PCT := 40
const LATE_TWO_PRODUCTS_PCT := 35
const LATE_THREE_PLUS_PCT := 25


static func pick_product_kind_count(
	rng: RandomNumberGenerator,
	game_day: int,
	pool_size: int
) -> int:
	var max_kinds := mini(pool_size, ProductCatalogScript.ORDER_MAX_UNITS)
	if max_kinds <= 1:
		return 1

	var factor := _day_factor(game_day)
	var one_pct := lerpf(float(DAY1_ONE_PRODUCT_PCT), float(LATE_ONE_PRODUCT_PCT), factor)
	var two_pct := lerpf(float(DAY1_TWO_PRODUCTS_PCT), float(LATE_TWO_PRODUCTS_PCT), factor)
	var three_plus_pct := lerpf(float(DAY1_THREE_PLUS_PCT), float(LATE_THREE_PLUS_PCT), factor)
	var roll := rng.randf() * (one_pct + two_pct + three_plus_pct)
	if roll < one_pct:
		return 1
	if roll < one_pct + two_pct:
		return mini(2, max_kinds)
	return mini(maxi(3, rng.randi_range(3, ProductCatalogScript.ORDER_MAX_UNITS)), max_kinds)


static func pick_line_quantity(
	rng: RandomNumberGenerator,
	game_day: int,
	product_kind_count: int
) -> int:
	if product_kind_count > 1:
		return 1
	var factor := _day_factor(game_day)
	# Single-product orders can occasionally ask for 2 units once the shop is established.
	var double_chance := lerpf(0.04, 0.22, factor)
	if rng.randf() < double_chance:
		return mini(2, ProductCatalogScript.ORDER_MAX_UNITS)
	return 1


static func _day_factor(game_day: int) -> float:
	return clampf(float(game_day - 1) / float(LATE_DAY - 1), 0.0, 1.0)
