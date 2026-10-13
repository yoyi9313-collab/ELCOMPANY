extends SceneTree
func _initialize():
 for m in GLTFDocument.new().get_method_list():
  if "write" in m.name or "generate" in m.name or "append" in m.name: print(m)
 quit()
