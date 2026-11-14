extends SceneTree
func _process(_d: float) -> bool:
	var bad := 0
	var n := 0
	var stack: Array = ["res://scripts", "res://dev"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var dir := DirAccess.open(d)
		if dir == null: continue
		for sub in dir.get_directories(): stack.append(d + "/" + sub)
		for f in dir.get_files():
			if f.ends_with(".gd"):
				n += 1
				var s = load(d + "/" + f)
				if s == null or not (s is GDScript) or not s.can_instantiate():
					bad += 1
					print("COMPILE FAIL ", d + "/" + f)
	print("COMPILE DONE files=", n, " bad=", bad)
	quit(1 if bad > 0 else 0)
	return true
