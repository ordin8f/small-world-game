extends GdUnitTestSuite
## Pure-function tests for scripts/logic/asset_mode.gd -- the detailed-
## vs-primitive courtyard toggle tools/_bootstrap_courtyard.gd's _kind()
## reads via AssetMode.resolve_detailed(). No scene/runner needed, same
## style as test_world_bounds.gd.
##
## These exercise the decision logic that determines whether BOTH toggle
## states build a valid level: resolve_detailed() is exactly what makes
## detailed mode fall back to a primitive instead of instancing a missing
## resource, which is the mechanism that keeps a partially-vendored
## asset pack from crashing the generator or shipping a scene with a
## dangling reference.

var _had_override: bool
var _original_value: Variant


func before_test() -> void:
	_had_override = ProjectSettings.has_setting(AssetMode.SETTING)
	_original_value = ProjectSettings.get_setting(AssetMode.SETTING, null)


func after_test() -> void:
	if _had_override:
		ProjectSettings.set_setting(AssetMode.SETTING, _original_value)
	else:
		ProjectSettings.set_setting(AssetMode.SETTING, null)


func test_defaults_to_detailed_when_the_project_setting_is_unset() -> void:
	ProjectSettings.set_setting(AssetMode.SETTING, null)
	assert_bool(AssetMode.use_detailed()).is_true()


func test_reads_the_project_setting_when_present() -> void:
	ProjectSettings.set_setting(AssetMode.SETTING, false)
	assert_bool(AssetMode.use_detailed()).is_false()

	ProjectSettings.set_setting(AssetMode.SETTING, true)
	assert_bool(AssetMode.use_detailed()).is_true()


func test_primitive_mode_never_resolves_a_detailed_asset() -> void:
	ProjectSettings.set_setting(AssetMode.SETTING, false)
	# A real, vendored path -- still false, because primitive mode wins.
	assert_bool(AssetMode.resolve_detailed("res://assets/park/bench.gltf")).is_false()


func test_detailed_mode_resolves_a_real_asset_and_falls_back_on_a_missing_one() -> void:
	ProjectSettings.set_setting(AssetMode.SETTING, true)
	assert_bool(AssetMode.resolve_detailed("res://assets/park/bench.gltf")).is_true()
	# Never crashes on a not-yet-vendored (or removed) path -- just says
	# "use the primitive fallback", same as primitive mode would.
	assert_bool(AssetMode.resolve_detailed("res://assets/park/does_not_exist.gltf")).is_false()
