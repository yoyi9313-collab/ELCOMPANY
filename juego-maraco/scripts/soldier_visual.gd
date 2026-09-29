extends SubViewport
## Cosmetic 3D render, composited into the existing 2D depth-sorted battlefield.
## No input, health, AP, occupancy or combat decisions live here.
const US_MODEL = preload("res://assets/soldiers/american/Meshy_AI_us_infantry_rigged_biped_Character_output.fbx")
const US_WALK = preload("res://assets/soldiers/american/Meshy_AI_us_infantry_rigged_biped_Animation_Walking_withSkin.fbx")
const GermanAssets = preload("res://scripts/german_visual_assets.gd")
const GERMAN_MODEL = GermanAssets.MODEL
const FIELD_SHADER = preload("res://assets/soldiers/field_material.gdshader")
var actor: Node3D
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var hostile := false
var state := ""
var phase_offset := 0.0
var previous_position := Vector2.ZERO
var camera: Camera3D
var weapon: Node3D
var right_hand := -1
var weapon_kind := ""
var posture := 1.0
var ground_bones: Array[int] = []
var grounding_enabled := true
const DRAW_SIZE := Vector2(56, 64)

static func remove_root_travel(animation: Animation, root_path: String) -> void:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or str(animation.track_get_path(track)) != root_path:
			continue
		var start: Vector3 = animation.track_get_key_value(track, 0)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			value.x = start.x
			value.z = start.z
			animation.track_set_key_value(track, key, value)

func setup(is_hostile: bool, member_index: int, member, squad_position: Vector2) -> void:
	hostile = is_hostile
	weapon_kind = member.weapon
	phase_offset = member_index * 0.19
	previous_position = squad_position
	size = Vector2i(112, 128)
	transparent_bg = true
	world_3d = World3D.new()
	gui_disable_input = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_2X
	var world := Node3D.new()
	add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0, 0, 0, 0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d5d6c4")
	environment.environment.ambient_light_energy = 0.75
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 0.45
	world.add_child(light)
	actor = Node3D.new()
	world.add_child(actor)
	model = (GERMAN_MODEL if hostile else US_MODEL).instantiate()
	actor.add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for bone_name in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		var index := skeleton.find_bone(bone_name)
		if index >= 0: ground_bones.append(index)
	process_priority = 10 # Correct contact after the AnimationPlayer updates bones.
	player = model.find_child("AnimationPlayer", true, false)
	for library_name in player.get_animation_library_list():
		player.remove_animation_library(library_name)
	player.add_animation_library("", GermanAssets.animations(skeleton, GermanAssets.RUN if hostile else US_WALK, "german" if hostile else "american"))
	prepare_imported_materials(model)
	build_weapon()
	add_role_equipment(member)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	camera.position = Vector3(0, 4.7, 7)
	camera.look_at(Vector3(0, 0.85, 0))
	camera.current = true
	set_animation("idle")
	player.advance(phase_offset)
	update_weapon()
	align_to_ground()

func add_role_equipment(member) -> void:
	# The Toon demo contains one rifle mesh. Equipment identifies its other roles
	# without changing that asset or assigning gameplay to individual members.
	if member.id not in ["ammo_bearer", "assistant"] and member.weapon not in ["BAR", "M1919", "MG42"]:
		return
	var case_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.27, 0.25, 0.18) if member.id != "ammo_bearer" else Vector3(0.40, 0.32, 0.24)
	case_mesh.mesh = box
	case_mesh.position = Vector3(-0.28, 0.95, -0.12)
	case_mesh.material_override = field_material(Color("616951") if hostile else Color("9a9463"))
	model.add_child(case_mesh)

func field_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FIELD_SHADER
	material.set_shader_parameter("uniform_color", color)
	return material

func build_weapon() -> void:
	# Basic Shooter supplies unarmed poses; these role-specific props are cosmetic.
	weapon = Node3D.new()
	model.add_child(weapon)
	right_hand = skeleton.find_bone("RightHand")
	if weapon_kind == "Kar98k":
		var rifle := GermanAssets.RIFLE.instantiate()
		rifle.name = "ImportedKar98"
		weapon.add_child(rifle)
		rifle.scale = Vector3.ONE * 0.58
		rifle.rotation.y = -PI * 0.5
		rifle.position = Vector3(0, -0.015, 0.25)
		prepare_imported_materials(rifle)
		return
	var heavy := weapon_kind in ["MG42", "M1919", "BAR"]
	var compact := weapon_kind in ["MP40", "Thompson", "M1 Carbine"]
	add_weapon_box(Vector3(0.075 if heavy else 0.055, 0.07, 0.65 if heavy else (0.30 if compact else 0.48)), Vector3(0, 0, 0.12), Color("393c35"))
	add_weapon_box(Vector3(0.035, 0.035, 0.36 if heavy else 0.25), Vector3(0, 0.02, 0.56 if heavy else 0.39), Color("272d2b"))
	add_weapon_box(Vector3(0.055, 0.09, 0.22), Vector3(0, -0.015, -0.22), Color("634732"))
	if compact or heavy:
		add_weapon_box(Vector3(0.055, 0.19, 0.075), Vector3(0, -0.10, 0.13), Color("383d33"))
	if heavy:
		add_weapon_box(Vector3(0.22, 0.12, 0.12), Vector3(0.11, -0.035, 0.15), Color("8a7852"))
	if weapon_kind == "M1919":
		add_weapon_box(Vector3(0.025, 0.45, 0.025), Vector3(-0.14, -0.25, 0.42), Color("303c32"))
		add_weapon_box(Vector3(0.025, 0.45, 0.025), Vector3(0.14, -0.25, 0.42), Color("303c32"))

func add_weapon_box(dimensions: Vector3, offset: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = offset
	part.material_override = field_material(color)
	weapon.add_child(part)

func set_animation(next: String) -> void:
	if state == next:
		return
	state = next
	player.play(next, 0.08)
	player.advance(0)
	update_weapon()

func update_weapon() -> void:
	if weapon != null and right_hand >= 0:
		weapon.position = model.to_local(skeleton.to_global(skeleton.get_bone_global_pose(right_hand).origin))
		var left := skeleton.find_bone("LeftHand")
		var support := model.to_local(skeleton.to_global(skeleton.get_bone_global_pose(left).origin))
		var direction := (support - weapon.position).normalized()
		if absf(direction.dot(Vector3.UP)) < 0.98:
			weapon.basis = Basis.looking_at(direction, Vector3.UP, true)

func sync(squad, member, firing: bool, throwing: bool, delta: float, hit_reaction: float = 0.0) -> void:
	grounding_enabled = member.alive
	var traveling: bool = squad.position.distance_to(previous_position) > 0.01
	previous_position = squad.position
	var next := "hit" if not member.alive or hit_reaction > 0.05 else ("fire" if firing else ("throw" if throwing else ("move" if traveling else "idle")))
	set_animation(next)
	# The camera looks down +Z; this matches the existing isometric projection.
	var screen_direction := Vector2(squad.facing.x - squad.facing.y, (squad.facing.x + squad.facing.y) * 0.5)
	actor.rotation.y = atan2(screen_direction.x, screen_direction.y * 2.0) + (member.facing * 0.055 if next == "idle" else 0.0)
	actor.rotation.z = 0.0 if member.alive else -member.casualty_progress() * 1.35
	var target_posture := 0.62 if squad.is_pinned() else (0.84 if squad.suppression > 0 else 1.0)
	if not member.alive: target_posture = 1.0
	posture = lerpf(posture, target_posture, 1.0 - exp(-12.0 * delta))
	actor.scale = Vector3(1, posture, 1)
	actor.rotation.x = (1.0 - posture) * 0.4 + sin(hit_reaction * PI) * 0.12
	actor.position.y = -sin(hit_reaction * PI) * 0.045
	update_weapon()
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if member.is_visible() else SubViewport.UPDATE_DISABLED

func draw_at(canvas: CanvasItem, position: Vector2, member) -> void:
	var alpha: float = 1.0 if member.alive else 1.0 - smoothstep(0.25, 1.0, member.casualty_progress())
	# Feet are aligned to each existing visual member's formation position.
	canvas.draw_texture_rect(get_texture(), Rect2(position + sprite_origin(), DRAW_SIZE), false, Color(1, 1, 1, alpha))

func sprite_origin() -> Vector2:
	# Project the actual ground plane, rather than guessing a texture margin.
	return -camera.unproject_position(Vector3.ZERO) * DRAW_SIZE / Vector2(size)

func align_to_ground() -> void:
	if not grounding_enabled or ground_bones.is_empty(): return
	skeleton.force_update_all_bone_transforms()
	var lowest := INF
	for bone in ground_bones:
		lowest = minf(lowest, skeleton.to_global(skeleton.get_bone_global_pose(bone).origin).y)
	# Foot joints sit just above the boot sole; preserve that small clearance.
	var sole_height := (0.055 if hostile else 0.065) * posture
	actor.position.y += sole_height - lowest

func _process(_delta: float) -> void:
	if not is_instance_valid(skeleton): return
	align_to_ground()
	update_weapon()

func muzzle_screen_offset() -> Vector2:
	var right := skeleton.find_bone("RightHand")
	var left := skeleton.find_bone("LeftHand")
	var grip := skeleton.to_global(skeleton.get_bone_global_pose(right).origin)
	var support := skeleton.to_global(skeleton.get_bone_global_pose(left).origin)
	var muzzle := support + (support - grip).normalized() * 0.28
	if hostile and weapon_kind == "Kar98k":
		muzzle = weapon.to_global(Vector3(0, -0.015, 0.80))
	return sprite_origin() + camera.unproject_position(muzzle) * DRAW_SIZE / Vector2(size)

func prepare_imported_materials(root_node: Node) -> void:
	for mesh: MeshInstance3D in root_node.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override != null: mesh.material_override = null
		for surface in mesh.mesh.get_surface_count():
			var original: StandardMaterial3D = mesh.mesh.surface_get_material(surface)
			var material := field_material(Color.WHITE)
			material.set_shader_parameter("use_texture", true)
			material.set_shader_parameter("albedo_texture", original.albedo_texture)
			mesh.set_surface_override_material(surface, material)
