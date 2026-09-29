extends SceneTree
const Visual = preload("res://scripts/soldier_visual.gd")
const Squad = preload("res://scripts/squad_data.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	for hostile in [false, true]:
		var squad := Squad.new(hostile)
		var member = squad.members[1] if hostile else squad.members[0]
		var visual := Visual.new()
		root.add_child(visual)
		visual.setup(hostile, 0, member, squad.position)
		if hostile:
			check(visual.model.scene_file_path.contains("Character_output"), "Germans use the supplied replacement character")
			check(visual.weapon.get_node_or_null("ImportedKar98") != null, "Riflemen carry the supplied KAR98 mesh")
		else:
			check(visual.model.scene_file_path.contains("american/Meshy_AI_us_infantry"), "Allies use the supplied americano character")
			check(visual.weapon_kind == "Thompson" and visual.weapon.get_child_count() > 0, "American leader retains role-specific weapon presentation")
		visual.sync(squad, member, false, false, 0.016)
		check(visual.state == "idle" and visual.player.is_playing(), "Faction idle animation plays")
		for clip in visual.player.get_animation_list():
			var animation: Animation = visual.player.get_animation(clip)
			for track in animation.get_track_count():
				var path: NodePath = animation.track_get_path(track)
				if path.get_subname_count() > 0:
					check(visual.skeleton.find_bone(path.get_subname(0)) >= 0, "Animation bone exists: " + str(path))
		squad.position += Vector2(4, 2)
		visual.sync(squad, member, false, false, 0.016)
		check(visual.state == "move", "Movement selects faction run clip")
		visual.sync(squad, member, true, false, 0.016)
		check(visual.state == "fire", "Normal and reaction volleys select firing clip")
		check(squad.action_points == 2 and squad.health == 400, "Animation never changes gameplay state")
		squad.health = 0
		visual.sync(squad, member, false, false, 0.016)
		check(visual.state == "hit", "Casualty selects cosmetic hit/fall")
		squad.restore()
		visual.sync(squad, member, false, false, 0.016)
		check(visual.state == "idle" and visual.actor.rotation.z == 0, "Battle reset restores living pose")
		squad.apply_suppression(1)
		visual.sync(squad, member, false, false, 1.0)
		var suppressed_height: float = visual.actor.scale.y
		check(suppressed_height < 0.9, "SUPPRESSED visibly lowers posture")
		squad.apply_suppression(1)
		visual.sync(squad, member, false, false, 1.0)
		check(visual.actor.scale.y < suppressed_height - 0.15, "PINNED has a stronger defensive posture")
		visual.sync(squad, member, false, false, 0.1, 1.0)
		check(visual.state == "hit", "Nonlethal impact triggers hit reaction")
		squad.restore()
		visual.sync(squad, member, false, false, 1.0)
		check(visual.actor.scale.y > 0.99, "Recovery restores upright posture")
		check(visual.ground_bones.size() >= 2, "Both factions have foot anchors")
		for clip_state in ["idle", "move", "fire"]:
			visual.set_animation(clip_state)
			for sample in 8:
				visual.player.advance(0.09)
				visual.align_to_ground()
				var lowest := INF
				for bone in visual.ground_bones:
					lowest = minf(lowest, visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(bone).origin).y)
				check(absf(lowest - (0.055 if hostile else 0.065) * visual.posture) < 0.001, "Boot contact remains grounded through " + clip_state)
				var grounded_position: float = visual.actor.position.y
				visual.align_to_ground()
				check(absf(visual.actor.position.y - grounded_position) < 0.001, "Grounding does not accumulate drift")
		check((visual.sprite_origin() + visual.camera.unproject_position(Vector3.ZERO) * visual.DRAW_SIZE / Vector2(visual.size)).length() < 0.01, "Rendered ground aligns exactly with logical formation anchor")
		visual.set_animation("idle")
		visual.set_animation("move")
		visual.player.advance(0.3)
		visual.set_animation("idle")
		visual.player.advance(0.2)
		visual.player.advance(0.01)
		check(visual.skeleton.get_bone_pose_position(0).is_equal_approx(visual.skeleton.get_bone_rest(0).origin), "Movement-to-idle restores root translation")
		if "--portrait" in OS.get_cmdline_user_args():
			if "--portrait-run" in OS.get_cmdline_user_args():
				visual.set_animation("move")
				visual.player.advance(0.25)
				visual.update_weapon()
			visual.size = Vector2i(448, 512)
			visual.actor.rotation.y = -0.45
			for i in 10:
				await process_frame
				visual.update_weapon()
			await RenderingServer.frame_post_draw
			visual.get_texture().get_image().save_png("res://tests/" + ("german" if hostile else "us") + "-portrait.png")
			for mesh in visual.model.find_children("*", "MeshInstance3D", true, false):
				if mesh.visible: print("VISIBLE ", mesh.name, " material override ", mesh.material_override, " surfaces ", mesh.mesh.get_surface_count())
		visual.queue_free()
		await process_frame
	print("SOLDIER ASSETS CHECKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
