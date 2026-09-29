extends RefCounted
## Presentation and roster state only. Members never own tiles, paths or turns.
## Alive state is synchronized by squad health; no member has independent HP.

var id: String
var role: String
var weapon: String
var offset: Vector2
var facing: float
var alive := true
var target_offset := Vector2.ZERO
var casualty_position := Vector2.ZERO
var casualty_time := 0.0
const CASUALTY_DURATION := 0.75

func _init(member_id: String, member_role: String, member_weapon: String, formation_offset: Vector2, facing_direction: float) -> void:
	id = member_id
	role = member_role
	weapon = member_weapon
	offset = formation_offset
	target_offset = formation_offset
	facing = facing_direction

func casualty_progress() -> float:
	return clampf(casualty_time / CASUALTY_DURATION, 0.0, 1.0)

func is_visible() -> bool:
	return alive or casualty_time < CASUALTY_DURATION
