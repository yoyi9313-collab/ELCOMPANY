extends RefCounted
const TITLE := "SECURE THE HEDGEROW"
const MAX_TURNS := 8
const REQUIRED_CAPTURE := 2
const ZONE: Array[Vector2i] = [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]
var capture_points := 0
var last_scored_turn := 0
var objective_status := "NEUTRAL"
var winner := ""
var reason := ""

func finished() -> bool:
	return not winner.is_empty()

func occupants(squads: Array) -> int:
	var count := 0
	for squad in squads:
		if squad.health > 0 and squad.cell in ZONE:
			count += 1
	return count

func update_status(allies: Array, enemies: Array) -> void:
	var friendly := occupants(allies) > 0
	var hostile := occupants(enemies) > 0
	objective_status = "CONTESTED" if friendly and hostile else ("ALLIED CONTROL" if friendly else "NEUTRAL")

func finish(side: String, explanation: String) -> void:
	if finished():
		return
	winner = side
	reason = explanation

func check_elimination(allies: Array, enemies: Array) -> void:
	if finished():
		return
	var allied_alive := allies.any(func(squad): return squad.health > 0)
	var enemy_alive := enemies.any(func(squad): return squad.health > 0)
	if not allied_alive:
		finish("GERMAN", "All Allied squads were eliminated.")
	elif not enemy_alive:
		finish("ALLIED", "All German squads were eliminated.")

func end_allied_phase(turn: int, allies: Array, enemies: Array) -> void:
	update_status(allies, enemies)
	check_elimination(allies, enemies)
	if finished() or turn <= last_scored_turn:
		return
	last_scored_turn = turn
	if objective_status == "ALLIED CONTROL":
		capture_points = mini(REQUIRED_CAPTURE, capture_points + 1)
		if capture_points == REQUIRED_CAPTURE:
			finish("ALLIED", "The central objective is secured.")

func end_german_phase(turn: int, allies: Array, enemies: Array) -> void:
	update_status(allies, enemies)
	check_elimination(allies, enemies)
	if not finished() and turn >= MAX_TURNS:
		finish("GERMAN", "Turn 8 ended before the objective was secured.")
