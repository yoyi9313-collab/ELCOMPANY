extends SceneTree
func _initialize():
 for file in ["model/ToonSoldier_WW2_demo.FBX", "animation/infantry_combat_idle.FBX"]:
  var scene = load("res://toon_soldiers_ww2/" + file).instantiate()
  print("FILE: ",file)
  scene.print_tree_pretty()
  for node in scene.find_children("*", "AnimationPlayer", true, false):
   for anim_name in node.get_animation_list():
    var a=node.get_animation(anim_name)
    print("ANIM ",anim_name," root ",node.root_node," tracks ",a.get_track_count()," duration ",a.length)
    for i in range(mini(3,a.get_track_count())): print(a.track_get_path(i))
  scene.free()
 quit()
