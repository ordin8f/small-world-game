class_name BootstrapSceneScriptBinder
extends RefCounted

## Reattaches a scene root script by editing the saved .tscn text.
##
## NOT named `_bootstrap_*` on purpose. Every other file in tools/ with that
## prefix is a runnable SceneTree generator you invoke with `--script`; this is a
## RefCounted helper the generators `preload()`. When it shared the prefix,
## something ran it as a main loop and Godot threw a modal alert -- which blocks
## the process, so the import never completed and the project stopped resolving
## gdUnit4 types, making the whole suite look broken.
## This avoids `load()`-time script compilation in --script mode while still
## guaranteeing scripted generators keep their `script = ExtResource(...)`
## binding even after regeneration.
static func bind_root_script(scene_path: String, script_path: String) -> bool:
	if scene_path.is_empty() or script_path.is_empty():
		return true

	if not ResourceLoader.exists(script_path):
		printerr("BootstrapSceneScriptBinder: script does not exist: ", script_path)
		return false

	var text := FileAccess.get_file_as_string(scene_path)
	if text == "":
		printerr("BootstrapSceneScriptBinder: could not read scene file: ", scene_path)
		return false

	var lines := text.split("\n")
	var script_id := ""
	var found_script_resource := false

	for i in range(lines.size()):
		var line := lines[i]
		if line.begins_with("[ext_resource") and line.find("type=\"Script\"") != -1 and line.find('path=\"%s\"' % script_path) != -1:
			script_id = _extract_resource_id(line)
			found_script_resource = true
			break

	if not found_script_resource:
		if script_id.is_empty():
			script_id = _slug_to_resource_id(script_path.get_file().get_basename())
			while _has_resource_id(lines, script_id):
				script_id = script_id + "_x"

		var ext_line := '[ext_resource type="Script" path="%s" id="%s"]' % [script_path, script_id]
		var insert_at := 1
		if lines.size() > insert_at and lines[insert_at].strip_edges() != "":
			lines.insert(insert_at, "")
			insert_at += 1
		lines.insert(insert_at, ext_line)

	var root_node_index := -1
	for i in range(lines.size()):
		if lines[i].begins_with("[node "):
			root_node_index = i
			break
	if root_node_index == -1:
		printerr("BootstrapSceneScriptBinder: could not find root node in: ", scene_path)
		return false

	var script_line_index := -1
	for i in range(root_node_index + 1, lines.size()):
		if lines[i].begins_with("["):
			break
		if lines[i].begins_with("script ="):
			script_line_index = i
			break

	var expected_script_line := 'script = ExtResource("%s")' % script_id
	if script_line_index == -1:
		lines.insert(root_node_index + 1, expected_script_line)
	else:
		lines[script_line_index] = expected_script_line

	var out := "\n".join(lines)
	var out_file := FileAccess.open(scene_path, FileAccess.WRITE)
	if out_file == null:
		printerr("BootstrapSceneScriptBinder: could not open scene file for write: ", scene_path)
		return false
	out_file.store_string(out)
	out_file.close()
	return true


static func _extract_resource_id(line: String) -> String:
	var start := line.find('id="')
	if start == -1:
		return ""
	start += 4
	var end := line.find('"', start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


static func _has_resource_id(lines: PackedStringArray, id_value: String) -> bool:
	var id_token := 'id="%s"' % id_value
	for line in lines:
		if line.find(id_token) != -1:
			return true
	return false


static func _slug_to_resource_id(value: String) -> String:
	var out := value.to_snake_case()
	if not out.is_valid_identifier():
		out = "script_" + out.to_lower()
	return "1_" + out + "_script"
