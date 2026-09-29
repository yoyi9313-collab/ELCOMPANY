extends RefCounted
signal tactical_stats_changed
## One tactical unit; members have presentation offsets, never independent tiles.
const Member = preload("res://scripts/squad_member.gd")
var name: String
var type: String
var hostile: bool
var player_controlled: bool
var max_health := 400
var _health := 400
var health: int:
	get: return _health
	set(value):
		_health = clampi(value, 0, max_health)
		if _health == 0:
			overwatch_active = false
		sync_members()
var movement: int
var attack_range := 3
var base_hit_chance := 85
var minimum_damage := 80
var maximum_damage := 110
var moved_this_turn := false
var stationary_accuracy_bonus := 0
var stationary_range_bonus := 0
var suppression_on_hit := 1
var suppression_on_miss := 0
var flank_damage_multiplier := 1.0
var rear_damage_multiplier := 1.0
var ai_role := "infantry"

func is_deployed() -> bool:
	return stationary_range_bonus > 0 and not moved_this_turn and not is_pinned()

func effective_attack_range() -> int:
	return attack_range + (stationary_range_bonus if not moved_this_turn and not is_pinned() else 0)

func effective_overwatch_range() -> int:
	return overwatch_range + (stationary_range_bonus if not moved_this_turn and not is_pinned() else 0)

func deployment_accuracy_bonus() -> int:
	return stationary_accuracy_bonus if not moved_this_turn and not is_pinned() else 0

func incoming_damage(raw_damage: int, attacker_cell: Vector2i) -> int:
	match incoming_sector(attacker_cell):
		"FLANK": return roundi(raw_damage * flank_damage_multiplier)
		"REAR": return roundi(raw_damage * rear_damage_multiplier)
	return raw_damage
const MAX_ACTION_POINTS := 2
var action_points := MAX_ACTION_POINTS
var attacks_this_turn := 0
var max_attacks_per_turn := 1
# Register future actions here; the shared spending API handles their AP cost.
var action_costs := {"move": 1, "fire": 1, "overwatch": 1, "grenade": 1}
var grenade_capacity := 1
var grenades_remaining := 1
var overwatch_active := false
var overwatch_fired := false
var overwatch_range := 3
var overwatch_accuracy_penalty := 15
var own_phase_active := false
var suppression_phases_remaining := 0
var suppression := 0:
	set(value):
		suppression = clampi(value, 0, 2)
		# A hit during our phase must survive the following full own phase too.
		suppression_phases_remaining = (2 if own_phase_active else 1) if suppression > 0 else 0
		if is_pinned():
			overwatch_active = false
		tactical_stats_changed.emit()

func is_pinned() -> bool:
	return suppression == 2

func suppression_state() -> String:
	return ["NORMAL", "SUPPRESSED", "PINNED"][suppression]
var facing := Vector2.RIGHT
var firing_arc_degrees := 120.0
var front_sector_degrees := 120.0
var rear_sector_degrees := 60.0

func face_direction(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		facing = direction.normalized()

func face_cell(target: Vector2i) -> void:
	face_direction(Vector2(target - cell))

func in_firing_arc(target: Vector2i) -> bool:
	var direction := Vector2(target - cell)
	if direction.is_zero_approx():
		return false
	return facing.normalized().dot(direction.normalized()) >= cos(deg_to_rad(clampf(firing_arc_degrees, 0.0, 360.0) * 0.5)) - 0.00001

func incoming_sector(attacker_cell: Vector2i) -> String:
	var direction := Vector2(attacker_cell - cell).normalized()
	var angle := rad_to_deg(acos(clampf(facing.normalized().dot(direction), -1.0, 1.0)))
	if angle <= front_sector_degrees * 0.5 + 0.00001:
		return "FRONT"
	if angle >= 180.0 - rear_sector_degrees * 0.5 - 0.00001:
		return "REAR"
	return "FLANK"

func can_perform(action: String) -> bool:
	if health <= 0 or not action_costs.has(action):
		return false
	if action == "grenade" and grenades_remaining <= 0:
		return false
	var reserved := 1 if overwatch_active else 0
	if action == "fire" and attacks_this_turn + reserved >= max_attacks_per_turn:
		return false
	if action == "overwatch" and (is_pinned() or overwatch_active or overwatch_fired or attacks_this_turn >= max_attacks_per_turn):
		return false
	return int(action_costs[action]) > 0 and action_points >= int(action_costs[action])

func spend_action(action: String) -> bool:
	if not can_perform(action):
		return false
	action_points -= int(action_costs[action])
	if action == "move":
		moved_this_turn = true
	if action == "grenade":
		grenades_remaining -= 1
	if action == "fire":
		attacks_this_turn += 1
	elif action == "overwatch":
		overwatch_active = true
	tactical_stats_changed.emit()
	return true

func can_react() -> bool:
	return health > 0 and not is_pinned() and overwatch_active and not overwatch_fired and attacks_this_turn < max_attacks_per_turn

func consume_overwatch_shot() -> bool:
	if not can_react():
		return false
	overwatch_active = false
	overwatch_fired = true
	attacks_this_turn += 1
	tactical_stats_changed.emit()
	return true

func effective_movement() -> int:
	return maxi(0, movement - suppression)

func accuracy_penalty() -> int:
	return 15 if suppression >= 2 else 0

func apply_suppression(points: int = 1) -> void:
	if points > 0:
		suppression = clampi(suppression + points, 0, 2)

func suppression_duration_text() -> String:
	if suppression == 0:
		return ""
	if not own_phase_active:
		return "THROUGH NEXT OWN PHASE"
	return "ACTIVE + NEXT OWN PHASE" if suppression_phases_remaining > 1 else "ACTIVE THIS PHASE"

func end_turn() -> void:
	if not own_phase_active:
		return
	own_phase_active = false
	if suppression > 0:
		suppression_phases_remaining -= 1
		if suppression_phases_remaining <= 0:
			suppression = 0
	tactical_stats_changed.emit()

func begin_turn() -> void:
	moved_this_turn = false
	own_phase_active = true
	action_points = MAX_ACTION_POINTS
	attacks_this_turn = 0
	overwatch_active = false
	overwatch_fired = false
	tactical_stats_changed.emit()

var cell: Vector2i
var position := Vector2.ZERO
var members: Array[Member] = []

func _init(is_enemy: bool = false, squad_size: int = 4, display_name: String = "", squad_type: String = "", total_health: int = 0, roster: Array[Dictionary] = [], stats: Dictionary = {}) -> void:
	hostile = is_enemy
	player_controlled = not is_enemy
	own_phase_active = player_controlled
	grenade_capacity = 0 if is_enemy else 1
	grenades_remaining = grenade_capacity
	name = "GRENADIERS" if is_enemy else "U.S. RANGERS"
	type = "INFANTRY SQUAD" if is_enemy else "ASSAULT SQUAD"
	if not display_name.is_empty():
		name = display_name
	if not squad_type.is_empty():
		type = squad_type
	var size := maxi(1, roster.size() if not roster.is_empty() else squad_size)
	max_health = total_health if total_health > 0 else size * 100
	_health = max_health
	movement = 4
	attack_range = stats.get("attack_range", 3)
	base_hit_chance = stats.get("base_hit_chance", 80 if is_enemy else 85)
	minimum_damage = stats.get("minimum_damage", 70 if is_enemy else 80)
	maximum_damage = stats.get("maximum_damage", 100 if is_enemy else 110)
	movement = stats.get("movement", 4)
	overwatch_range = attack_range
	stationary_accuracy_bonus = stats.get("stationary_accuracy_bonus", 0)
	ai_role = stats.get("ai_role", "infantry")
	stationary_range_bonus = stats.get("stationary_range_bonus", 0)
	suppression_on_hit = stats.get("suppression_on_hit", 1)
	suppression_on_miss = stats.get("suppression_on_miss", 0)
	flank_damage_multiplier = stats.get("flank_damage_multiplier", 1.0)
	rear_damage_multiplier = stats.get("rear_damage_multiplier", 1.0)
	overwatch_accuracy_penalty = stats.get("overwatch_accuracy_penalty", 15)
	grenade_capacity = stats.get("grenade_capacity", grenade_capacity)
	grenades_remaining = grenade_capacity
	cell = Vector2i(8, 1) if is_enemy else Vector2i(3, 7)
	facing = Vector2(-5, 6).normalized() if is_enemy else Vector2(5, -6).normalized()
	# Wider spacing, still inside one diamond. Offsets have no occupancy cost.
	var offsets := formation_offsets(size)
	var ids := ["leader", "rifleman", "bar_gunner", "carbine"]
	var roles := ["SQUAD LEADER", "RIFLEMAN", "BAR GUNNER", "CARBINE RIFLEMAN"]
	var weapons := ["Thompson", "M1 Garand", "BAR", "M1 Carbine"]
	if is_enemy:
		ids = ["leader", "rifleman_1", "rifleman_2", "mg_gunner"]
		roles = ["SQUAD LEADER", "RIFLEMAN", "RIFLEMAN", "MG GUNNER"]
		weapons = ["MP40", "Kar98k", "Kar98k", "MG42"]
	var facings := [-1.0, 0.85, -0.9, 1.0]
	for i in size:
		var definition: Dictionary = roster[i] if not roster.is_empty() else {}
		var member_id: String = definition.get("id", ids[i] if i < 4 else "rifleman_%d" % i)
		var role: String = definition.get("role", roles[i] if i < 4 else "RIFLEMAN")
		var weapon: String = definition.get("weapon", weapons[i] if i < 4 else weapons[1])
		var member_facing: float = definition.get("facing", facings[i % 4])
		members.append(Member.new(member_id, role, weapon, offsets[i], -absf(member_facing) if is_enemy else member_facing))

func expected_member_count() -> int:
	return ceili(float(health) * members.size() / max_health)

func sync_members() -> void:
	# Stable roster order keeps the leader until last. Changes reflect only squad HP.
	var survivors := expected_member_count()
	var offsets := formation_offsets(survivors)
	for i in members.size():
		var member := members[i]
		var should_live := i < survivors
		if member.alive and not should_live:
			member.casualty_position = position + member.offset
			member.casualty_time = 0.0
		elif not member.alive and should_live:
			member.casualty_time = 0.0
		member.alive = should_live
		if should_live:
			member.target_offset = offsets[i]

func restore() -> void:
	suppression = 0
	grenades_remaining = grenade_capacity
	health = max_health
	begin_turn()
	own_phase_active = player_controlled
	for member in members:
		member.offset = member.target_offset
		member.casualty_time = 0.0

func update_visuals(delta: float) -> void:
	for member in members:
		if member.alive:
			member.offset = member.offset.lerp(member.target_offset, 1.0 - exp(-7.0 * delta))
		else:
			member.casualty_time = minf(Member.CASUALTY_DURATION, member.casualty_time + delta)

static func formation_offsets(count: int) -> Array[Vector2]:
	match count:
		0: return []
		1: return [Vector2(0, 0)]
		2: return [Vector2(-16, -3), Vector2(16, 3)]
		3: return [Vector2(-26, 0), Vector2(0, -8), Vector2(26, 2)]
		4: return [Vector2(-32, 0), Vector2(-11, -10), Vector2(10, 10), Vector2(32, -1)]
		5: return [Vector2(-32, 0), Vector2(-16, -9), Vector2(0, 11), Vector2(16, -9), Vector2(32, 0)]
	var offsets: Array[Vector2] = []
	for i in count:
		var angle := TAU * float(i) / count
		offsets.append(Vector2(cos(angle) * 27, sin(angle) * 10))
	return offsets

func visible_members() -> Array[Member]:
	var result: Array[Member] = []
	for member in members:
		if member.is_visible():
			result.append(member)
	return result

func living_members() -> Array[Member]:
	var result: Array[Member] = []
	for member in members:
		if member.alive:
			result.append(member)
	return result

func member_position(member: Member) -> Vector2:
	return position + member.offset if member.alive else member.casualty_position

func hit_test(point: Vector2) -> bool:
	for member in living_members():
		if Rect2(member_position(member) + Vector2(-9, -32), Vector2(18, 35)).has_point(point):
			return true
	return false
