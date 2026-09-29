extends RefCounted
const Terrain = preload("res://scripts/terrain_rules.gd")

static func trace_cells(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	# Integer supercover traversal between tile centers. At an exact corner,
	# include both touching cells: rays cannot slip through a blocked corner.
	var result: Array[Vector2i] = [start]
	var delta := target - start
	var nx := absi(delta.x)
	var ny := absi(delta.y)
	var step := Vector2i(signi(delta.x), signi(delta.y))
	var current := start
	var ix := 0
	var iy := 0
	while ix < nx or iy < ny:
		var crossing := (1 + 2 * ix) * ny - (1 + 2 * iy) * nx
		if crossing == 0:
			result.append(current + Vector2i(step.x, 0))
			result.append(current + Vector2i(0, step.y))
			current += step
			ix += 1
			iy += 1
		elif crossing < 0:
			current.x += step.x
			ix += 1
		else:
			current.y += step.y
			iy += 1
		result.append(current)
	return result

static func is_clear(start: Vector2i, target: Vector2i, terrain: Dictionary) -> bool:
	for cell in trace_cells(start, target):
		if cell != start and cell != target and Terrain.blocks_los(terrain.get(cell)):
			return false
	return true
