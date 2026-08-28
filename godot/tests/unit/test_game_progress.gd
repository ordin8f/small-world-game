extends GdUnitTestSuite
## Unit test for game.gd's Gate 0 additions: the single sanctioned save
## (SAVE_PATH -- "a 'completed once' flag; nothing more", per
## PRODUCT_CONTRACT.md) and the treasures_found clamp. Cleans up the real
## save file afterward so running the suite never leaves the developer's
## own game looking "already completed" on its next launch.

func after_test() -> void:
	Game.completed_once = false
	Game.treasures_found = 0
	var abs_path := ProjectSettings.globalize_path(Game.SAVE_PATH)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func test_treasures_found_clamps_to_zero_through_three() -> void:
	Game.set_treasures_found(-4)
	assert_int(Game.treasures_found).is_equal(0)
	Game.set_treasures_found(2)
	assert_int(Game.treasures_found).is_equal(2)
	Game.set_treasures_found(99)
	assert_int(Game.treasures_found).is_equal(3)


func test_mark_completed_persists_to_disk() -> void:
	assert_bool(Game.completed_once).is_false()
	Game.mark_completed()
	assert_bool(Game.completed_once).is_true()

	# Independent of this process's in-memory flag -- proves it actually
	# round-trips through SAVE_PATH, the way a fresh relaunch would read it.
	assert_bool(Game._load_completed_flag()).is_true()


func test_present_as_completed_sets_director_to_complete() -> void:
	Game.director.state = EpisodeDirector.State.ARRIVE
	Game._present_as_completed()
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.COMPLETE)
