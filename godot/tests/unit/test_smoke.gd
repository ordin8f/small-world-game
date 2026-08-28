extends GdUnitTestSuite
## M0.3 smoke test: confirms the gdUnit4 CLI runner is wired up correctly.

func test_smoke_arithmetic() -> void:
	assert_int(2 + 2).is_equal(4)
