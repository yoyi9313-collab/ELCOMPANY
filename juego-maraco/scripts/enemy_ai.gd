extends RefCounted
const Terrain = preload("res://scripts/terrain_rules.gd")
const LOS = preload("res://scripts/line_of_sight.gd")
## Pure, deterministic planner. Fixed neighbor order breaks otherwise equal ties.
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func objective_route(start: Vector2i, zone: Array[Vector2i], support: bool, budget: int, size: int, obstacles: Dictionary, attack_range: int, occupied: Array[Vector2i]) -> Array[Vector2i]:
	if budget <= 0 or (not support and start in zone):
		return []
	var paths := search(start, Vector2i(-1, -1), size, obstacles, occupied)
	var best := start
	var best_score := 2147483647
	for cell: Vector2i in paths.order:
		if not support and cell not in zone:
			continue
		if support:
			if cell in zone:
				continue
			var overlooks := false
			for goal in zone:
				if distance(cell, goal) <= attack_range and clear_firing_lane(cell, goal, obstacles):
					overlooks = true
					break
			if not overlooks:
				continue
		var score: int = paths.costs[cell] * 10
		if support and not has_cover(cell, obstacles):
			score += 1000
		if score < best_score:
			best_score = score
			best = cell
	if best == start:
		return []
	var planned := route(start, best, paths.parents)
	planned.resize(mini(budget, planned.size()))
	return planned

static func has_cover(cell: Vector2i, obstacles: Dictionary) -> bool:
	return Terrain.adjacent_cover(cell, obstacles) > 0

static func clear_firing_lane(start: Vector2i, target: Vector2i, obstacles: Dictionary) -> bool:
	return LOS.is_clear(start, target, obstacles)

static func search(start: Vector2i, blocked_cell: Vector2i, size: int, obstacles: Dictionary, occupied: Array[Vector2i] = []) -> Dictionary:
	var costs := {start: 0}
	var parents := {}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var next := current + direction
			if next.x < 0 or next.y < 0 or next.x >= size or next.y >= size:
				continue
			if next == blocked_cell or next in occupied or Terrain.blocks_movement(obstacles.get(next)) or costs.has(next):
				continue
			costs[next] = costs[current] + 1
			parents[next] = current
			queue.append(next)
	return {"costs": costs, "parents": parents, "order": queue}

static func route(start: Vector2i, destination: Vector2i, parents: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := destination
	while current != start:
		result.push_front(current)
		current = parents[current]
	return result

static func plan(start: Vector2i, target: Vector2i, budget: int, size: int, obstacles: Dictionary, attack_range: int = 3, occupied: Array[Vector2i] = [], require_lane: bool = true) -> Array[Vector2i]:
	if budget <= 0 or (distance(start, target) <= attack_range and (not require_lane or clear_firing_lane(start, target, obstacles))):
		return []
	var paths := search(start, target, size, obstacles, occupied)
	var from_target := search(target, Vector2i(-1, -1), size, obstacles, occupied)
	var best := start
	var best_score := 2147483647
	var current_distance: int = from_target.costs.get(start, 2147483647)
	for cell: Vector2i in paths.order:
		if cell == start or paths.costs[cell] > budget:
			continue
		if not has_cover(cell, obstacles) and distance(cell, target) > attack_range:
			continue
		if require_lane and not clear_firing_lane(cell, target, obstacles):
			continue
		# Useful cover either enables a shot or advances along a route to the target.
		if distance(cell, target) > attack_range and from_target.costs.get(cell, 2147483647) >= current_distance:
			continue
		var position_score: int = int(from_target.costs.get(cell, 999)) * 100 if has_cover(cell, obstacles) else 5000
		var score: int = maxi(0, distance(cell, target) - attack_range) * 10000 + position_score + int(paths.costs[cell])
		if score < best_score:
			best = cell
			best_score = score
	if best != start:
		return route(start, best, paths.parents)
	# BFS's first firing tile has the shortest valid approach route.
	for cell: Vector2i in paths.order:
		if distance(cell, target) <= attack_range and (not require_lane or clear_firing_lane(cell, target, obstacles)):
			var full_route := route(start, cell, paths.parents)
			full_route.resize(mini(budget, full_route.size()))
			return full_route
	return []
