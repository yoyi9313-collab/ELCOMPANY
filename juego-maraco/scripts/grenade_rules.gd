extends RefCounted
const Terrain = preload("res://scripts/terrain_rules.gd")
## Tile-based blast rules shared by previews, damage and future squad types.
const RANGE := 2
const DIRECT_MIN := 170
const DIRECT_MAX := 210
const ADJACENT_MIN := 85
const ADJACENT_MAX := 110
const NEIGHBORS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func blast_cells(center: Vector2i, board: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in [Vector2i.ZERO] + NEIGHBORS:
		var cell: Vector2i = center + offset
		if cell.x >= 0 and cell.y >= 0 and cell.x < board and cell.y < board:
			cells.append(cell)
	return cells

static func protection(cell: Vector2i, cover: Dictionary) -> float:
	# Match the existing adjacency-based cover system; strongest cover wins.
	var strength := Terrain.adjacent_cover(cell, cover)
	return 0.25 if strength >= 2 else (0.10 if strength == 1 else 0.0)

static func damage(raw_damage: int, cell: Vector2i, cover: Dictionary) -> int:
	return roundi(raw_damage * (1.0 - protection(cell, cover)))
