extends Node
## Presentation-only effects and optional local audio hooks. No gameplay RNG.
signal audio_cue(kind: String)
@export var rifle_sound: AudioStream
@export var machine_gun_sound: AudioStream
@export var grenade_sound: AudioStream
@export var movement_sound: AudioStream
@export var ui_sound: AudioStream
@export_range(0.0, 1.0) var shake_strength := 1.0
var impacts: Array[Dictionary] = []
var reactions: Dictionary = {}
var shake_left := 0.0
var shake_amount := 0.0
var focus_left := 0.0
var focus_offset := Vector2.ZERO
var camera_offset := Vector2.ZERO
var elapsed := 0.0
var audio_players: Array[AudioStreamPlayer] = []
var audio_index := 0

func _ready() -> void:
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		audio_players.append(player)

func cue(kind: String) -> void:
	audio_cue.emit(kind)
	var stream: AudioStream = {"rifle": rifle_sound, "machine_gun": machine_gun_sound, "grenade": grenade_sound, "move": movement_sound}.get(kind, ui_sound)
	if stream == null or audio_players.is_empty(): return
	var player := audio_players[audio_index % audio_players.size()]
	audio_index += 1
	player.stream = stream
	player.play()

func shake(amount: float, seconds: float) -> void:
	shake_amount = maxf(amount, shake_amount)
	shake_left = maxf(shake_left, seconds)

func focus(point: Vector2) -> void:
	# At most six pixels of attention; never pan away or pause player control.
	focus_offset = (Vector2(640, 410) - point).limit_length(6)
	focus_left = 0.65

func impact(point: Vector2, on_cover: bool, delay: float = 0.0) -> void:
	impacts.append({"point": point, "cover": on_cover, "age": -delay})

func hit(squad, casualty: bool) -> void:
	reactions[squad] = 0.32
	if casualty: focus(squad.position)

func reaction(squad) -> float:
	return clampf(float(reactions.get(squad, 0.0)) / 0.32, 0, 1)

func reset() -> void:
	impacts.clear()
	reactions.clear()
	shake_left = 0
	shake_amount = 0
	focus_left = 0
	camera_offset = Vector2.ZERO
	for player in audio_players: player.stop()

func _process(delta: float) -> void:
	elapsed += delta
	for effect in impacts: effect.age += delta
	impacts = impacts.filter(func(effect): return effect.age < 0.42)
	for squad in reactions.keys():
		reactions[squad] -= delta
		if reactions[squad] <= 0: reactions.erase(squad)
	shake_left = maxf(0, shake_left - delta)
	focus_left = maxf(0, focus_left - delta)
	if shake_left == 0: shake_amount = 0
	var amplitude := shake_amount * minf(1, shake_left / 0.3) * shake_strength
	camera_offset = Vector2(sin(elapsed * 81), cos(elapsed * 67) * 0.6) * amplitude
	camera_offset += focus_offset * sin(clampf(focus_left / 0.65, 0, 1) * PI) * shake_strength

func draw_on(canvas: CanvasItem) -> void:
	for effect in impacts:
		var age: float = effect.age
		if age < 0: continue
		var alpha := 1.0 - age / 0.42
		var point: Vector2 = effect.point
		var color := Color("e4c787") if effect.cover else Color("b7a886")
		canvas.draw_circle(point + Vector2(0, -age * 13), 3 + age * 14, Color(color, alpha * 0.35))
		for i in 5:
			var direction := Vector2(cos(i * 2.4), -absf(sin(i * 2.4)))
			var start := point + direction * age * 25
			canvas.draw_line(start, start + direction * (4 if effect.cover else 2), Color(color, alpha), 1.6, true)
		if age < 0.08: canvas.draw_circle(point, 2.5, Color(1, 0.9, 0.6, alpha))
