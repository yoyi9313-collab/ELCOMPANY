extends SceneTree
func _initialize():
 var doc=GLTFDocument.new()
 var state=GLTFState.new()
 assert(doc.append_from_file("res://toon_soldiers_ww2/soldado_ww2.glb",state)==OK)
 var model=doc.generate_scene(state)
 root.add_child(model)
 var meshes=model.find_children("*","MeshInstance3D",true,false)
 assert(meshes.size()>0)
 for mesh in meshes:
  for i in mesh.mesh.get_surface_count():
   var mat=mesh.mesh.surface_get_material(i)
   assert(mat.albedo_texture!=null,"Missing texture")
 var player=model.find_child("AnimationPlayer",true,false)
 assert(player!=null)
 var skeleton=model.find_child("Skeleton3D",true,false)
 assert(skeleton!=null)
 for anim in ["combat_idle","combat_run","combat_shoot","guard_idle"]:
  assert(player.has_animation(anim))
  player.play(anim)
  player.advance(0.2)
  for i in skeleton.get_bone_count(): assert(skeleton.get_bone_pose(i).is_finite())
  print("OK ",anim," duration=",player.get_animation(anim).length)
 print("OK: GLB reloaded; embedded texture; ",meshes.size()," mesh(es); ",skeleton.get_bone_count()," bones")
 model.queue_free()
 quit()
