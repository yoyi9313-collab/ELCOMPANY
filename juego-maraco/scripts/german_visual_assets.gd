extends RefCounted
## Maps the supplied Meshy humanoid onto the existing cosmetic shooter clips.
const MODEL = preload("res://assets/soldiers/grenadier/Meshy_AI_wwii_grenadier_lowpol_biped_Character_output.fbx")
const RIFLE = preload("res://assets/weapons/kar98/Meshy_AI_Create_a_game_ready_l_0924073935_texture.fbx")
const RUN = preload("res://assets/soldiers/grenadier/Meshy_AI_wwii_grenadier_lowpol_biped_Animation_Running_withSkin.fbx")
const BONES := {"Hips": "Hips", "Spine02": "Spine", "Spine01": "Spine1", "Spine": "Spine2", "neck": "Neck", "Head": "Head", "LeftShoulder": "LeftShoulder", "LeftArm": "LeftArm", "LeftForeArm": "LeftForeArm", "LeftHand": "LeftHand", "RightShoulder": "RightShoulder", "RightArm": "RightArm", "RightForeArm": "RightForeArm", "RightHand": "RightHand", "LeftUpLeg": "LeftUpLeg", "LeftLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToeBase", "RightUpLeg": "RightUpLeg", "RightLeg": "RightLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToeBase"}
const CHILD := {"Hips": "Spine02", "Spine02": "Spine01", "Spine01": "Spine", "Spine": "neck", "neck": "Head", "Head": "head_end", "LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand", "LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase", "RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase"}
static var libraries: Dictionary = {}

static func animations(target: Skeleton3D, movement_scene: PackedScene = RUN, profile: String = "german") -> AnimationLibrary:
	if libraries.has(profile): return libraries[profile]
	var library := AnimationLibrary.new()
	for key in {"idle": "rifle aiming idle", "fire": "firing rifle", "hit": "hit reaction", "throw": "toss grenade"}:
		var file: String = {"idle": "rifle aiming idle", "fire": "firing rifle", "hit": "hit reaction", "throw": "toss grenade"}[key]
		var source: Node3D = load("res://assets/soldiers/german/" + file + ".fbx").instantiate()
		source.visible = false
		target.add_child(source)
		var rig: Skeleton3D = source.find_child("Skeleton3D", true, false)
		var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false)
		var clip: StringName = player.get_animation_list()[0]
		var animation := Animation.new()
		animation.length = player.get_animation(clip).length
		animation.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "fire"] else Animation.LOOP_NONE
		var target_basis := target.global_basis.orthonormalized()
		var corrections: Dictionary = {}
		var indices: Dictionary = {}
		for name in BONES:
			var ti := target.find_bone(name)
			var si := rig.find_bone("mixamorig_" + BONES[name])
			indices[ti] = si
			var target_rest_basis := target_basis * target.get_bone_global_rest(ti).basis.orthonormalized()
			var sr := rig.get_bone_global_rest(si).basis.orthonormalized()
			var adjustment := Basis.IDENTITY
			if CHILD.has(name) and BONES.has(CHILD[name]):
				var tc := target.find_bone(CHILD[name])
				var sc := rig.find_bone("mixamorig_" + BONES[CHILD[name]])
				var td := target_basis * (target.get_bone_global_rest(tc).origin - target.get_bone_global_rest(ti).origin)
				var sd := rig.get_bone_global_rest(sc).origin - rig.get_bone_global_rest(si).origin
				adjustment = Basis(Quaternion(td.normalized(), sd.normalized()))
			corrections[ti] = sr.inverse() * adjustment * target_rest_basis
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, "Armature/Skeleton3D:" + name)
		var frames := ceili(animation.length * 30)
		player.play(clip)
		for frame in range(frames + 1):
			var time := minf(frame / 30.0, animation.length)
			player.seek(time, true)
			rig.force_update_all_bone_transforms()
			var poses: Dictionary = {}
			for ti in range(target.get_bone_count()):
				if indices.has(ti):
					poses[ti] = target_basis.inverse() * rig.get_bone_global_pose(indices[ti]).basis.orthonormalized() * corrections[ti]
				else:
					var parent := target.get_bone_parent(ti)
					poses[ti] = poses[parent] * target.get_bone_rest(ti).basis if parent >= 0 else target.get_bone_rest(ti).basis
			var track := 0
			for name in BONES:
				var ti := target.find_bone(name)
				var parent := target.get_bone_parent(ti)
				var local: Basis = poses[parent].inverse() * poses[ti] if parent >= 0 else poses[ti]
				animation.rotation_track_insert_key(track, time, local.orthonormalized().get_rotation_quaternion())
				track += 1
		var root_position := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(root_position, "Armature/Skeleton3D:Hips")
		animation.position_track_insert_key(root_position, 0, target.get_bone_rest(0).origin)
		library.add_animation(key, animation)
		source.free()
	var run_source := movement_scene.instantiate()
	var run_player: AnimationPlayer = run_source.find_child("AnimationPlayer", true, false)
	var running: Animation = run_player.get_animation(run_player.get_animation_list()[0]).duplicate(true)
	running.loop_mode = Animation.LOOP_LINEAR
	# Native file uses Z-up skeleton coordinates: lock horizontal X/Y travel.
	for track in running.get_track_count():
		if running.track_get_type(track) == Animation.TYPE_POSITION_3D:
			var first: Vector3 = running.track_get_key_value(track, 0)
			for key in running.track_get_key_count(track):
				var value: Vector3 = running.track_get_key_value(track, key)
				value.x = first.x
				value.y = first.y
				running.track_set_key_value(track, key, value)
		elif running.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			# Retain the native run in the legs and torso; keep both hands on the
			# weapon instead of letting the supplied unarmed arm swing detach it.
			var bone: String = running.track_get_path(track).get_subname(0)
			if "Shoulder" in bone or "Arm" in bone or "Hand" in bone:
				var idle := library.get_animation("idle")
				var idle_track := idle.find_track(running.track_get_path(track), Animation.TYPE_ROTATION_3D)
				for key in running.track_get_key_count(track):
					running.track_set_key_value(track, key, idle.track_get_key_value(idle_track, 0))
	library.add_animation("move", running)
	run_source.free()
	libraries[profile] = library
	return library
