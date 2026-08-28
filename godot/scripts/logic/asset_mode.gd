class_name AssetMode
extends RefCounted
## Detailed-vs-primitive courtyard asset toggle, read by
## tools/_bootstrap_courtyard.gd at generation time (see that file's own
## doc comment for the registry it drives). Static utility class, same
## shape as WorldBounds/LensMath -- no scene or autoload dependency.
##
## Backed by a ProjectSettings key, not the Game autoload: the generator
## runs standalone via `godot --headless --path godot --script
## res://tools/_bootstrap_courtyard.gd`, and autoloads are not registered
## that early in a bare --script run (see _bootstrap_player_scene.gd's
## doc comment for the same constraint on Game). ProjectSettings has no
## such restriction -- it is populated from project.godot before any user
## code runs -- and is settable without opening a scene: edit
## project.godot's [small_world] section directly, or Project Settings ->
## small_world/assets/use_detailed in the editor.
##
## Flip the setting, then re-run:
##   godot --headless --path godot --script res://tools/_bootstrap_courtyard.gd
##   godot --headless --path godot --import
## main.tscn instances courtyard.tscn (ExtResource, not a baked copy) so
## it never needs regenerating itself.

const SETTING := "small_world/assets/use_detailed"
const DEFAULT_USE_DETAILED := true


static func use_detailed() -> bool:
	return ProjectSettings.get_setting(SETTING, DEFAULT_USE_DETAILED)


## Whether `path` should actually be instanced as a detailed prop: true
## only when detailed mode is on AND the resource genuinely resolves.
## False covers both primitive mode and a detailed-mode asset that was
## never vendored (or got removed) -- callers should build their
## primitive fallback either way and push_warning() in the latter case,
## so a missing asset is loud in the generator's own output instead of
## crashing it or shipping a scene with a dangling reference.
static func resolve_detailed(path: String) -> bool:
	return use_detailed() and ResourceLoader.exists(path)
