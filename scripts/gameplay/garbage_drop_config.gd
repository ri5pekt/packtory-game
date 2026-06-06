class_name GarbageDropConfig
extends RefCounted

## Tuning for customer litter drops near the queue lane.

const DROP_CHANCE_ON_ARRIVE := 0.22
const DROP_CHANCE_ON_DEPART := 0.18
const MAX_GARBAGE_PIECES := 12

const MINI_MARKET := "res://blender/assets/kenney_mini-market/Models/GLB format/"
const HOUSEHOLD := "res://blender/assets/Household Props 001-glb/"

## Small props from existing kits that read as floor litter when scaled down.
const LITTER_MODELS := [
	MINI_MARKET + "bottle-return.glb",
	MINI_MARKET + "shopping-basket.glb",
	HOUSEHOLD + "Hamburger.glb",
]

const MODEL_SCALE := 0.28
const CLICK_LAYER := 1
