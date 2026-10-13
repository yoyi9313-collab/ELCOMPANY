extends SceneTree
func _initialize():
 var soldier = load("res://toon_soldiers_ww2/model/ToonSoldier_WW2_demo.FBX").instantiate()
 root.add_child(soldier)
 var skeleton = soldier.find_child("Skeleton3D",true,false)
 var mat = StandardMaterial3D.new()
 mat.resource_name = "US_soldier_simple"
 mat.albedo_texture = load("res://toon_soldiers_ww2/model/Materials/US_soldier_simple.tga")
 mat.roughness=1.0
 for mesh in soldier.find_children("*","MeshInstance3D",true,false):
  mesh.mesh=mesh.mesh.duplicate()
  for surface in mesh.mesh.get_surface_count(): mesh.mesh.surface_set_material(surface,mat)
 var player=AnimationPlayer.new()
 player.name="AnimationPlayer"
 soldier.add_child(player)
 player.owner=soldier
 var library=AnimationLibrary.new()
 player.add_animation_library("",library)
 for clip in ["combat_idle","combat_run","combat_shoot","guard_idle"]:
  var src=load("res://toon_soldiers_ww2/animation/infantry_"+clip+".FBX").instantiate()
  var source_player=src.find_child("AnimationPlayer",true,false)
  var anim=source_player.get_animation(source_player.get_animation_list()[0]).duplicate(true)
  for track in anim.get_track_count():
   var path=anim.track_get_path(track)
   if path.get_subname_count()>0:
    assert(skeleton.find_bone(path.get_subname(0))>=0,"Missing bone: "+str(path))
  if clip!="combat_shoot": anim.loop_mode=Animation.LOOP_LINEAR
  library.add_animation(clip,anim)
  print("Animation verified: ",clip," duration=",anim.length," tracks=",anim.get_track_count())
  src.free()
 var document=GLTFDocument.new()
 var state=GLTFState.new()
 assert(document.append_from_scene(soldier,state)==OK)
 assert(document.write_to_filesystem(state,"res://toon_soldiers_ww2/soldado_ww2.glb")==OK)
 print("GLB exported. Bones: ",skeleton.get_bone_count())
 soldier.queue_free()
 quit()

