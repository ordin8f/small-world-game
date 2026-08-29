extends SceneTree
## Fails the build when a vendored .glb/.gltf references a file that is not in
## the repository -- an external texture, or a .bin buffer.
##
## Why this exists: roof-high-point.glb from Kenney's Fantasy Town Kit does not
## embed its atlas, it references `Textures/colormap.png` relative to itself.
## Only the .glb files were vendored, so that reference resolved to nothing.
## glTF has no albedo colour to fall back on when a baseColorTexture is missing,
## so the material imported as pure white -- and with the scene's glow pass on
## top, two tower roofs rendered as glowing white lampshades, brighter than
## anything else in frame. Every model in that kit shares one atlas, so all four
## vendored from it had the same defect latent in them.
##
## Nothing caught it. The generator ran clean (the .glb itself loads fine), all
## 95 tests stayed green (none of them look at a pixel), and the asset ledger
## said the kit was textured. It took a human opening a PNG. That is exactly the
## class of bug worth a cheap mechanical check: the question "does every file
## this model asks for actually exist" needs no renderer and no eyes.
##
## Run: godot --headless --path godot --script res://tools/_check_asset_textures.gd
## Exits 1 and lists every unresolved reference; wired into tools/verify.ps1.

const ASSET_ROOT := "res://assets"

var _missing: Array[String] = []
var _untextured: Array[String] = []
var _checked := 0
var _refs := 0


func _init() -> void:
	_scan(ASSET_ROOT)
	if _missing.is_empty() and _untextured.is_empty():
		print("asset textures: %d model(s), %d external reference(s), all resolved and applied." % [_checked, _refs])
		quit()
		return
	if not _missing.is_empty():
		printerr("asset textures: %d unresolved reference(s) --" % _missing.size())
		for line in _missing:
			printerr("  " + line)
		printerr("Vendor the missing file(s) next to the model, or re-material the")
		printerr("model so it carries a baseColorFactor instead of a texture.")
	if not _untextured.is_empty():
		printerr("asset textures: %d model(s) declare a baseColorTexture but imported WITHOUT one --" % _untextured.size())
		for line in _untextured:
			printerr("  " + line)
		printerr("The file is present but Godot's cached import predates it. Delete the")
		printerr("model's .import sibling and re-run --import.")
	quit(1)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_scan(full)
		elif name.get_extension().to_lower() in ["glb", "gltf"]:
			_check_model(full)
		name = dir.get_next()
	dir.list_dir_end()


func _check_model(path: String) -> void:
	var json := _read_gltf_json(path)
	if json.is_empty():
		return
	_checked += 1
	# `images` covers textures; `buffers` covers the .bin a .gltf splits its mesh
	# data into -- both are external references that can go missing the same way.
	for key in ["images", "buffers"]:
		for entry in json.get(key, []):
			if typeof(entry) != TYPE_DICTIONARY or not entry.has("uri"):
				continue  # embedded in a bufferView; nothing to resolve
			var uri: String = entry["uri"]
			if uri.begins_with("data:"):
				continue  # inlined base64
			_refs += 1
			var resolved := path.get_base_dir().path_join(uri.uri_decode())
			if not FileAccess.file_exists(resolved):
				_missing.append("%s -> %s (%s)" % [path, uri, key])

	# Second pass, and the one that actually catches the rendered symptom. A
	# present file is NOT sufficient: vendoring the atlas alone left these four
	# models still importing white, because Godot had already cached an import
	# from when the texture was absent and the .glb's own mtime had not moved,
	# so --import considered them up to date. Checking that the model DECLARES a
	# baseColorTexture and that the imported material actually HAS one catches
	# both that and the missing-file case.
	if _declares_base_color_texture(json):
		_check_imported_texture(path)


func _declares_base_color_texture(json: Dictionary) -> bool:
	for mat in json.get("materials", []):
		if typeof(mat) != TYPE_DICTIONARY:
			continue
		var pbr: Dictionary = mat.get("pbrMetallicRoughness", {})
		if pbr.has("baseColorTexture"):
			return true
	return false


func _check_imported_texture(path: String) -> void:
	var packed: Resource = load(path)
	if packed == null or not (packed is PackedScene):
		return
	var root: Node = (packed as PackedScene).instantiate()
	if not _any_albedo_texture(root):
		_untextured.append(path)
	root.free()  # this script instantiates scenes purely to inspect them


func _any_albedo_texture(n: Node) -> bool:
	if n is MeshInstance3D:
		var m: Mesh = (n as MeshInstance3D).mesh
		if m != null:
			for i in range(m.get_surface_count()):
				var mat := m.surface_get_material(i)
				if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
					return true
	for c in n.get_children():
		if _any_albedo_texture(c):
			return true
	return false


## The JSON chunk of a .glb, or the whole file for a .gltf. Returns {} for
## anything unreadable rather than erroring: this check is about missing
## SIBLINGS, and a model Godot itself cannot parse will fail the import step
## long before it gets here.
func _read_gltf_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := ""
	if path.get_extension().to_lower() == "gltf":
		text = file.get_as_text()
	else:
		# glb: 12-byte header, then chunks of [u32 length][u32 type][payload].
		# The first chunk is required by the spec to be the JSON one.
		if file.get_length() < 20 or file.get_buffer(4).get_string_from_ascii() != "glTF":
			return {}
		file.seek(12)
		var chunk_len := file.get_32()
		var chunk_type := file.get_32()
		if chunk_type != 0x4E4F534A:  # 'JSON'
			return {}
		text = file.get_buffer(chunk_len).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
