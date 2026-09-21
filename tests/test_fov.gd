## Testy całkowitoliczbowego pola widzenia.
##
## Czysty test rdzenia: bez sceny, bez Timerów, bez inputu, bez czasu rzeczywistego.
extends GdUnitTestSuite

const OBSERVER := Vector2i(10, 10)
const VIEW_RANGE := 5


## Przypadki brzegowe FOV we wszystkich czterech kierunkach kardynalnych.
## Kolumny: obserwator, kierunek, zasięg, cel, oczekiwana widoczność, opis.
func test_fov_cases(
		observer: Vector2i,
		facing: Vector2i,
		view_range: int,
		target: Vector2i,
		expected: bool,
		description: String,
		test_parameters := [
			# --- RIGHT ---
			[Vector2i(10, 10), Vector2i(1, 0), 5, Vector2i(13, 10), true, "RIGHT: z przodu w zasiegu"],
			[Vector2i(10, 10), Vector2i(1, 0), 5, Vector2i(7, 10), false, "RIGHT: za obserwatorem"],
			[Vector2i(10, 10), Vector2i(1, 0), 5, Vector2i(16, 10), false, "RIGHT: poza zasiegiem"],
			[Vector2i(10, 10), Vector2i(1, 0), 5, Vector2i(15, 10), true, "RIGHT: dokladnie na granicy zasiegu"],
			[Vector2i(10, 10), Vector2i(1, 0), 5, Vector2i(13, 13), true, "RIGHT: dokladnie na granicy kata"],
			[Vector2i(10, 10), Vector2i(1, 0), 5, Vector2i(12, 12), true, "RIGHT: granica kata, druga strona"],
			[Vector2i(10, 10), Vector2i(1, 0), 5, Vector2i(13, 14), false, "RIGHT: poza katem"],
			[Vector2i(10, 10), Vector2i(1, 0), 5, Vector2i(10, 10), false, "RIGHT: ta sama komorka"],
			# --- LEFT ---
			[Vector2i(10, 10), Vector2i(-1, 0), 5, Vector2i(7, 10), true, "LEFT: z przodu w zasiegu"],
			[Vector2i(10, 10), Vector2i(-1, 0), 5, Vector2i(13, 10), false, "LEFT: za obserwatorem"],
			[Vector2i(10, 10), Vector2i(-1, 0), 5, Vector2i(4, 10), false, "LEFT: poza zasiegiem"],
			[Vector2i(10, 10), Vector2i(-1, 0), 5, Vector2i(5, 10), true, "LEFT: dokladnie na granicy zasiegu"],
			[Vector2i(10, 10), Vector2i(-1, 0), 5, Vector2i(7, 7), true, "LEFT: dokladnie na granicy kata"],
			[Vector2i(10, 10), Vector2i(-1, 0), 5, Vector2i(7, 14), false, "LEFT: poza katem"],
			[Vector2i(10, 10), Vector2i(-1, 0), 5, Vector2i(10, 10), false, "LEFT: ta sama komorka"],
			# --- DOWN ---
			[Vector2i(10, 10), Vector2i(0, 1), 5, Vector2i(10, 13), true, "DOWN: z przodu w zasiegu"],
			[Vector2i(10, 10), Vector2i(0, 1), 5, Vector2i(10, 7), false, "DOWN: za obserwatorem"],
			[Vector2i(10, 10), Vector2i(0, 1), 5, Vector2i(10, 16), false, "DOWN: poza zasiegiem"],
			[Vector2i(10, 10), Vector2i(0, 1), 5, Vector2i(10, 15), true, "DOWN: dokladnie na granicy zasiegu"],
			[Vector2i(10, 10), Vector2i(0, 1), 5, Vector2i(13, 13), true, "DOWN: dokladnie na granicy kata"],
			[Vector2i(10, 10), Vector2i(0, 1), 5, Vector2i(14, 13), false, "DOWN: poza katem"],
			[Vector2i(10, 10), Vector2i(0, 1), 5, Vector2i(10, 10), false, "DOWN: ta sama komorka"],
			# --- UP ---
			[Vector2i(10, 10), Vector2i(0, -1), 5, Vector2i(10, 7), true, "UP: z przodu w zasiegu"],
			[Vector2i(10, 10), Vector2i(0, -1), 5, Vector2i(10, 13), false, "UP: za obserwatorem"],
			[Vector2i(10, 10), Vector2i(0, -1), 5, Vector2i(10, 4), false, "UP: poza zasiegiem"],
			[Vector2i(10, 10), Vector2i(0, -1), 5, Vector2i(10, 5), true, "UP: dokladnie na granicy zasiegu"],
			[Vector2i(10, 10), Vector2i(0, -1), 5, Vector2i(7, 7), true, "UP: dokladnie na granicy kata"],
			[Vector2i(10, 10), Vector2i(0, -1), 5, Vector2i(6, 7), false, "UP: poza katem"],
			[Vector2i(10, 10), Vector2i(0, -1), 5, Vector2i(10, 10), false, "UP: ta sama komorka"],
		]) -> void:
	assert_bool(FovCalculator.is_target_visible(observer, facing, view_range, target)) \
		.append_failure_message(description) \
		.is_equal(expected)


## Granica zasięgu po przekątnej: kwadrat odległości decyduje, nie suma osi.
func test_range_uses_squared_distance() -> void:
	# (3,4) -> 9 + 16 = 25, dokladnie na granicy zasiegu 5.
	assert_bool(FovCalculator.is_target_visible(OBSERVER, Vector2i(1, 0), VIEW_RANGE, Vector2i(13, 14))) \
		.append_failure_message("cel (3,4) lezy poza katem mimo granicy zasiegu") \
		.is_false()
	# (4,3) -> 16 + 9 = 25, w zasiegu i w kacie.
	assert_bool(FovCalculator.is_target_visible(OBSERVER, Vector2i(1, 0), VIEW_RANGE, Vector2i(14, 13))) \
		.append_failure_message("cel (4,3) powinien byc widoczny na granicy zasiegu") \
		.is_true()


## Zerowy zasięg nie widzi niczego, łącznie z sąsiednią komórką.
func test_zero_range_sees_nothing() -> void:
	assert_bool(FovCalculator.is_target_visible(OBSERVER, Vector2i(1, 0), 0, Vector2i(11, 10))).is_false()
	assert_bool(FovCalculator.is_target_visible(OBSERVER, Vector2i(1, 0), 0, OBSERVER)).is_false()
