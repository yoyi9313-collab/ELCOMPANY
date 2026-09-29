extends RefCounted
## Mission setup only. Deployment never spends AP or advances a phase.
const INTRO := "INTRO"
const DEPLOYMENT := "DEPLOYMENT"
const BATTLE := "BATTLE"
var stage := INTRO
var placed: Dictionary = {}

static func in_deployment_zone(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= 5 and cell.y >= 7 and cell.y <= 9

func can_place(squad, cell: Vector2i, squads: Array, cover: Dictionary) -> bool:
	if stage != DEPLOYMENT or not squad.player_controlled or squad.health <= 0 or not in_deployment_zone(cell):
		return false
	if preload("res://scripts/terrain_rules.gd").blocks_movement(cover.get(cell)):
		return false
	return not squads.any(func(other): return other != squad and other.health > 0 and other.cell == cell)

func ready(allies: Array) -> bool:
	return stage == DEPLOYMENT and allies.all(func(squad): return placed.has(squad))

static func summary(mission, turn: int, allies: Array, enemies: Array) -> Dictionary:
	var casualties := 0
	var survivors := 0
	var destroyed := 0
	for squad in allies:
		casualties += squad.members.size() - squad.living_members().size()
		if squad.health > 0: survivors += 1
	for squad in enemies:
		if squad.health == 0: destroyed += 1
	return {"result": "VICTORY" if mission.winner == "ALLIED" else "DEFEAT", "turns": mini(turn, 8), "survivors": survivors, "casualties": casualties, "destroyed": destroyed}
