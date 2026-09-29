extends RefCounted
## Shared terrain properties. String entries remain supported for saved fixtures.
static func properties(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	match str(value):
		"crate", "light":
			return {"kind": "crate", "blocks_los": true, "blocks_movement": true, "provides_cover": true, "cover_strength": 1}
		"sandbags", "heavy":
			return {"kind": "sandbags", "blocks_los": false, "blocks_movement": true, "provides_cover": true, "cover_strength": 2}
	return {}

static func blocks_los(value: Variant) -> bool:
	return properties(value).get("blocks_los", false)

static func blocks_movement(value: Variant) -> bool:
	return properties(value).get("blocks_movement", false)

static func cover_strength(value: Variant) -> int:
	var data := properties(value)
	return int(data.get("cover_strength", 0)) if data.get("provides_cover", false) else 0

static func adjacent_cover(cell: Vector2i, terrain: Dictionary) -> int:
	var strength := 0
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		strength = maxi(strength, cover_strength(terrain.get(cell + direction)))
	return strength

static func cover_name(cell: Vector2i, terrain: Dictionary) -> String:
	match adjacent_cover(cell, terrain):
		0: return "NONE"
		1: return "LIGHT"
	return "HEAVY"
