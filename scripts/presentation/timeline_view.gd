## Oś czasu przebiegu: gdzie jesteśmy i kiedy w tym incydencie coś się działo.
##
## Czysta prezentacja. Dane bierze z tego, co już policzył rdzeń — numeru ticka,
## limitu ticków i kopii event logu. Nie liczy niczego na potrzeby logiki i nie
## dotyka stanu domenowego.
##
## Skala: oś pokazuje domyślnie pierwsze [constant DEFAULT_HORIZON] ticków, bo
## incydenty L0 kończą się w okolicach 20–40 ticka, a limit scenariusza wynosi
## 400 — rozciąganie osi do limitu ścisnęłoby cały przebieg w lewy margines.
## Gdy przebieg wyjdzie poza horyzont, ten podwaja się do granicy `max_ticks`.
class_name TimelineView
extends Node2D

const WIDTH := 560.0
const HEIGHT := 26.0
const DEFAULT_HORIZON := 40
## Zapas nad i pod paskiem, żeby kliknięcie nie wymagało celowania co do piksela.
const HIT_PADDING := 8.0

const COLOR_TRACK := Color(0.13, 0.14, 0.17, 1.0)
const COLOR_TRACK_BORDER := Color(0.30, 0.33, 0.38, 1.0)
const COLOR_ELAPSED := Color(0.20, 0.30, 0.40, 1.0)
const COLOR_GRID := Color(0.24, 0.26, 0.30, 1.0)
const COLOR_MARK := Color(0.98, 0.72, 0.25, 1.0)
const COLOR_TERMINAL := Color(0.95, 0.35, 0.30, 1.0)
const COLOR_CURSOR := Color(1.0, 1.0, 1.0, 0.95)
const COLOR_TEXT := Color(0.62, 0.66, 0.72, 1.0)

var _tick := 0
var _horizon := DEFAULT_HORIZON
var _event_ticks: Array[int] = []
var _terminal_tick := -1


## [param event_ticks] to ticki zdarzeń wartych uwagi, [param terminal_tick]
## to tick zakończenia przebiegu albo -1, gdy incydent trwa.
func render(snapshot: Dictionary, event_ticks: Array[int], terminal_tick: int) -> void:
	_tick = int(snapshot["tick"])
	_horizon = _compute_horizon(int(snapshot["max_ticks"]), _tick)
	_event_ticks = event_ticks
	_terminal_tick = terminal_tick
	queue_redraw()


func horizon() -> int:
	return _horizon


## Obszar kliknięcia — nieco wyższy niż sam pasek, żeby trafienie było wygodne.
## Zwykła matematyka prostokąta: żadnego Area2D ani kolizji.
func hit_rect() -> Rect2:
	return Rect2(Vector2(0.0, -HIT_PADDING), Vector2(WIDTH, HEIGHT + HIT_PADDING * 2.0))


func contains_global_point(global_point: Vector2) -> bool:
	return hit_rect().has_point(to_local(global_point))


## Tick odpowiadający wskazanemu punktowi na pasku.
func tick_at_global_point(global_point: Vector2) -> int:
	var x := clampf(to_local(global_point).x, 0.0, WIDTH)
	return int(roundf(float(_horizon) * x / WIDTH))


static func _compute_horizon(max_ticks: int, tick: int) -> int:
	var horizon := mini(max_ticks, DEFAULT_HORIZON)
	while tick > horizon and horizon < max_ticks:
		horizon = mini(max_ticks, horizon * 2)
	return maxi(horizon, 1)


func _tick_to_x(tick: int) -> float:
	return WIDTH * (float(clampi(tick, 0, _horizon)) / float(_horizon))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), COLOR_TRACK, true)

	# Przebyta część osi.
	var cursor_x := _tick_to_x(_tick)
	if cursor_x > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(cursor_x, HEIGHT)), COLOR_ELAPSED, true)

	_draw_decade_grid()

	# Znaczniki zdarzeń.
	for tick: int in _event_ticks:
		var x := _tick_to_x(tick)
		var color := COLOR_TERMINAL if tick == _terminal_tick else COLOR_MARK
		draw_line(Vector2(x, 3.0), Vector2(x, HEIGHT - 3.0), color, 2.0)

	# Kursor bieżącego ticka.
	draw_line(Vector2(cursor_x, 0.0), Vector2(cursor_x, HEIGHT), COLOR_CURSOR, 2.0)

	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), COLOR_TRACK_BORDER, false, 1.0)
	_draw_labels()


## Kreski co 10 ticków dają skali punkt odniesienia.
func _draw_decade_grid() -> void:
	var step := 10
	var tick := step
	while tick < _horizon:
		var x := _tick_to_x(tick)
		draw_line(Vector2(x, HEIGHT - 6.0), Vector2(x, HEIGHT), COLOR_GRID, 1.0)
		tick += step


func _draw_labels() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var size := ThemeDB.fallback_font_size
	draw_string(font, Vector2(0.0, HEIGHT + 14.0), "tick 0",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, COLOR_TEXT)
	draw_string(font, Vector2(WIDTH - 60.0, HEIGHT + 14.0), "%d" % _horizon,
		HORIZONTAL_ALIGNMENT_RIGHT, 60.0, size, COLOR_TEXT)
	draw_string(font, Vector2(0.0, -6.0), "przebieg: tick %d   (kliknij, aby przewinąć)" % _tick,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, COLOR_TEXT)
