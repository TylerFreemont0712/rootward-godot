extends GdUnitTestSuite
## How skins are imported. An A-pose rig needs Godot's silhouette fixer (it re-aims the limbs to the T-pose the
## moves were keyed in), but the fixer also re-aims the feet and tips the toes up; every skin that uses it leaves the
## feet out.

const FEET: Array[String] = ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]


func _imports(folder: String, found: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".glb.import") or file.ends_with(".vrm.import"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		_imports(folder.path_join(sub), found)


func test_a_skin_with_the_silhouette_fixer_keeps_its_feet_out_of_it() -> void:
	var found: Array[String] = []
	_imports("res://characters", found)
	assert_bool(found.is_empty()).is_false()
	for path in found:
		var text := FileAccess.get_file_as_string(path)
		if not text.contains('"retarget/rest_fixer/fix_silhouette/enable": true'):
			continue
		for foot in FEET:
			(
				assert_str(text)
				. override_failure_message("%s: the silhouette fixer would tip %s up" % [path, foot])
				. contains('&"%s"' % foot)
			)
