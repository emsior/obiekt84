## Koordynator sceny L0: wybór wariantu incydentu, adapter czasu, obsługa
## wejścia i odświeżanie widoku.
##
## Timer jest wyłącznie tempem wizualnym — nie jest zegarem domenowym.
## Każdy timeout wywołuje najwyżej jeden jawny step(). Jitter Timera nie może
## zmienić wyniku logicznego, bo rdzeń nie widzi delty ani czasu rzeczywistego.
##
## Warianty incydentu to wyłącznie **różne dane wejściowe** tego samego silnika
## L0 — nie zmieniają żadnej reguły gry. Każdy startuje od świeżych danych
## `ScenarioL0.create()`; dwa z nich zmieniają dokładnie jedno pole.
## Konfiguracja żyje tutaj, bo potrzebuje jej wyłącznie warstwa prezentacji.
extends Node2D

enum ScenarioVariant {
	DETECTION,
	SUCCESS,
	TICK_LIMIT,
}

## Zasięg widzenia strażnika w wariancie sukcesu. Przy tej wartości strażnik
## dostrzega intruza na jeden tick, gubi cel, wraca do patrolu, a intruz kończy
## trasę. Wynik powstaje normalną pracą silnika.
const SUCCESS_GUARD_VIEW_RANGE := 4

## Limit ticków w wariancie limitu. Wykrycie wypada w 38 ticku, więc przebieg
## urywa się naturalnie, zanim którykolwiek aktor osiągnie stan terminalny.
const TICK_LIMIT_MAX_TICKS := 20

const VARIANT_NAMES := {
	ScenarioVariant.DETECTION: "WYKRYCIE",
	ScenarioVariant.SUCCESS: "SUKCES INTRUZA",
	ScenarioVariant.TICK_LIMIT: "LIMIT TICKÓW",
}

@onready var _level_view: LevelView = $LevelL0
@onready var _hud: Hud = $HudLayer/Hud
@onready var _step_timer: Timer = $StepTimer

var _simulation: Simulation = null
var _variant: ScenarioVariant = ScenarioVariant.DETECTION
var _running := false
var _overlay_visible := true
var _log_visible := true


func _ready() -> void:
	_step_timer.wait_time = Simulation.SECONDS_PER_TICK
	_step_timer.one_shot = false
	_step_timer.timeout.connect(_on_step_timeout)

	_hud.start_requested.connect(_on_start_requested)
	_hud.pause_toggle_requested.connect(_on_pause_toggle_requested)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.variant_requested.connect(select_variant)

	_level_view.set_overlay_visible(_overlay_visible)
	_rebuild_simulation()


## Sterowanie klawiaturą. Wejście należy wyłącznie do warstwy prezentacji —
## rdzeń nigdy go nie widzi.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_1:
			select_variant(ScenarioVariant.DETECTION)
		KEY_2:
			select_variant(ScenarioVariant.SUCCESS)
		KEY_3:
			select_variant(ScenarioVariant.TICK_LIMIT)
		KEY_SPACE:
			_on_pause_toggle_requested()
		KEY_N:
			single_step()
		KEY_R:
			_on_restart_requested()
		KEY_F:
			toggle_overlay()
		KEY_L:
			toggle_log()
		KEY_ESCAPE:
			pause()
		_:
			return
	get_viewport().set_input_as_handled()


# === warianty incydentu =======================================================

## Wybór wariantu natychmiast restartuje przebieg na świeżych danych.
## Poprzednia instancja Simulation jest porzucana, nie wznawiana.
func select_variant(variant: ScenarioVariant) -> void:
	_variant = variant
	_rebuild_simulation()


func current_variant() -> ScenarioVariant:
	return _variant


func current_variant_name() -> String:
	return String(VARIANT_NAMES[_variant])


## Świeże dane wejściowe dla aktualnego wariantu. Zawsze zaczynamy od
## ScenarioL0.create(); warianty zmieniają najwyżej jedno pole.
func _build_scenario() -> ScenarioL0:
	var scenario := ScenarioL0.create()
	match _variant:
		ScenarioVariant.SUCCESS:
			scenario.guard_view_range = SUCCESS_GUARD_VIEW_RANGE
		ScenarioVariant.TICK_LIMIT:
			scenario.max_ticks = TICK_LIMIT_MAX_TICKS
		_:
			pass
	return scenario


## Świeża symulacja na świeżych danych plus czysty stan prezentacji.
func _rebuild_simulation() -> void:
	_stop()
	_simulation = Simulation.new()
	_simulation.initialize(_build_scenario())
	_render()


# === sterowanie przebiegiem ===================================================

## Jeden timeout to dokładnie jedno wywołanie step().
func _on_step_timeout() -> void:
	if not _running:
		return
	single_step()


## Pojedynczy krok symulacji. Po stanie terminalnym jest bezpiecznym no-op —
## rdzeń i tak odrzuca dalsze step(), a tutaj dodatkowo zatrzymujemy odtwarzanie.
func single_step() -> void:
	if _simulation.is_finished():
		_stop()
		_render()
		return

	_simulation.step()

	if _simulation.is_finished():
		_stop()
	_render()


func _on_start_requested() -> void:
	if _simulation.is_finished() or _running:
		return
	_running = true
	_step_timer.start()
	_render()


func _on_pause_toggle_requested() -> void:
	if _simulation.is_finished():
		return
	if _running:
		_stop()
	else:
		_running = true
		_step_timer.start()
	_render()


## Escape zawsze prowadzi do neutralnego, zatrzymanego stanu.
func pause() -> void:
	if not _running:
		return
	_stop()
	_render()


## Restart odtwarza **aktualnie wybrany** wariant, nie wraca do domyślnego.
func _on_restart_requested() -> void:
	_rebuild_simulation()


func toggle_overlay() -> void:
	_overlay_visible = not _overlay_visible
	_level_view.set_overlay_visible(_overlay_visible)
	_render()


func toggle_log() -> void:
	_log_visible = not _log_visible
	_render()


func _stop() -> void:
	_running = false
	_step_timer.stop()


## Widok i HUD czytają wyłącznie snapshot oraz kopię logu.
func _render() -> void:
	var snapshot := _simulation.get_state_snapshot()
	_level_view.render(snapshot)
	_hud.render(
		snapshot,
		_simulation.get_last_events(Hud.LOG_LINES),
		_running,
		_simulation.is_finished(),
		_overlay_visible,
		_log_visible,
		int(_variant),
		current_variant_name())
