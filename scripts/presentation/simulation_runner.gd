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

## Tempo automatycznego przebiegu. To wyłącznie odstęp czasu między kolejnymi
## wywołaniami step() — zawartość ticka, ich kolejność, FOV, FSM, event log
## i wynik pozostają bez zmian. Rdzeń nadal nie widzi czasu rzeczywistego.
const PLAYBACK_SPEEDS: Array[float] = [0.5, 1.0, 2.0]
const PLAYBACK_SPEED_LABELS: Array[String] = ["Wolno", "Normalnie", "Szybko"]
const DEFAULT_SPEED_INDEX := 1

## Zdarzenie rutynowe — mijanie waypointu nie zasługuje na podświetlenie,
## bo strażnik robi to co kilka ticków. Wszystko inne jest decyzją albo wynikiem.
const ROUTINE_EVENT := "WAYPOINT_REACHED"

@onready var _level_view: LevelView = $LevelL0
@onready var _timeline: TimelineView = $Timeline
@onready var _hud: Hud = $HudLayer/Hud
@onready var _step_timer: Timer = $StepTimer

var _simulation: Simulation = null
var _variant: ScenarioVariant = ScenarioVariant.DETECTION
var _speed_index := DEFAULT_SPEED_INDEX
var _running := false
var _overlay_visible := true
var _log_visible := true


func _ready() -> void:
	_step_timer.one_shot = false
	_step_timer.timeout.connect(_on_step_timeout)
	_apply_speed()

	_hud.start_requested.connect(_on_start_requested)
	_hud.pause_toggle_requested.connect(_on_pause_toggle_requested)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.variant_requested.connect(select_variant)
	_hud.speed_requested.connect(select_speed_index)
	_hud.step_back_requested.connect(step_back)
	_hud.step_forward_requested.connect(single_step)

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
		KEY_N, KEY_PERIOD:
			single_step()
		KEY_COMMA:
			step_back()
		KEY_R:
			_on_restart_requested()
		KEY_F:
			toggle_overlay()
		KEY_L:
			toggle_log()
		KEY_BRACKETLEFT:
			step_speed(-1)
		KEY_BRACKETRIGHT:
			step_speed(1)
		KEY_ESCAPE:
			pause()
		_:
			return
	get_viewport().set_input_as_handled()


# === tempo automatycznego przebiegu ===========================================

## Zmiana tempa o jeden stopień: -1 wolniej, +1 szybciej. Na krańcach zostaje
## przy skrajnej wartości. Nie rusza ticka, logu, wariantu ani stanu auto-run.
func step_speed(direction: int) -> void:
	select_speed_index(clampi(_speed_index + direction, 0, PLAYBACK_SPEEDS.size() - 1))


func select_speed_index(index: int) -> void:
	var clamped := clampi(index, 0, PLAYBACK_SPEEDS.size() - 1)
	if clamped == _speed_index:
		return
	_speed_index = clamped
	_apply_speed()
	_render()


func set_playback_speed(multiplier: float) -> void:
	var index := PLAYBACK_SPEEDS.find(multiplier)
	if index < 0:
		push_warning("Nieznany mnoznik tempa: %s" % str(multiplier))
		return
	select_speed_index(index)


func playback_speed() -> float:
	return PLAYBACK_SPEEDS[_speed_index]


func playback_speed_index() -> int:
	return _speed_index


func playback_speed_label() -> String:
	return PLAYBACK_SPEED_LABELS[_speed_index]


## Odstęp prezentacji między automatycznymi krokami.
func step_interval() -> float:
	return Simulation.SECONDS_PER_TICK / playback_speed()


## Przeliczenie interwału Timera. W trakcie odtwarzania restartujemy Timer,
## żeby nowe tempo obowiązywało już przed kolejnym automatycznym tickiem.
## `start()` nie emituje timeout, więc przełączenie nie wykonuje dodatkowego kroku.
func _apply_speed() -> void:
	_step_timer.wait_time = step_interval()
	if _running:
		_step_timer.start()


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
	seek_to_tick(0)


## Przewinięcie przebiegu do wskazanego ticka.
##
## Działa **dzięki determinizmowi rdzenia**: nie ma cofania stanu ani historii
## snapshotów — budujemy świeżą symulację na tych samych danych i wykonujemy
## dokładnie [param target] kroków. Ten sam scenariusz zawsze daje ten sam
## przebieg, więc odtworzony tick jest identyczny z oryginalnym.
##
## Przewijanie zatrzymuje automatyczny przebieg i zachowuje wariant oraz tempo.
func seek_to_tick(target: int) -> void:
	_stop()
	_simulation = Simulation.new()
	_simulation.initialize(_build_scenario())
	for i in range(maxi(0, target)):
		if _simulation.is_finished():
			break
		_simulation.step()
	_render()


## Cofnięcie o jeden tick. Na ticku 0 nie robi nic.
func step_back() -> void:
	var tick := _simulation.get_tick()
	if tick <= 0:
		return
	seek_to_tick(tick - 1)


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


# === wyróżnienie tego, co wydarzyło się w bieżącym ticku ======================

## Zdarzenia z bieżącego ticka, które są warte uwagi testera.
## Wyliczane z danych, które i tak już mamy — rdzeń nic o tym nie wie.
func notable_events() -> Array[Dictionary]:
	var tick := _simulation.get_tick()
	var notable: Array[Dictionary] = []
	for entry: Dictionary in _simulation.get_last_events(Hud.LOG_LINES):
		if int(entry["tick"]) == tick and String(entry["event"]) != ROUTINE_EVENT:
			notable.append(entry)
	return notable


## Komórki podmiotów, których dotyczą zdarzenia bieżącego ticka.
## Dzięki temu tester widzi na planszy dokładnie to, co czyta w logu.
func highlight_cells() -> Array[Vector2i]:
	var snapshot := _simulation.get_state_snapshot()
	var cells: Array[Vector2i] = []
	for entry: Dictionary in notable_events():
		var subject := String(entry["subject"])
		var cell := Vector2i.ZERO
		var found := false
		if subject == String(snapshot["guard_id"]):
			cell = snapshot["guard_position"]
			found = true
		elif subject == String(snapshot["intruder_id"]):
			cell = snapshot["intruder_position"]
			found = true
		elif subject == String(snapshot["camera_id"]):
			cell = snapshot["camera_position"]
			found = true
		if found and not cells.has(cell):
			cells.append(cell)
	return cells


## Ticki całego przebiegu, w których wydarzyło się coś innego niż rutynowe
## minięcie waypointu — materiał na znaczniki osi czasu.
func timeline_event_ticks() -> Array[int]:
	var ticks: Array[int] = []
	for entry: Dictionary in _simulation.get_event_log():
		if String(entry["event"]) == ROUTINE_EVENT:
			continue
		var tick := int(entry["tick"])
		if not ticks.has(tick):
			ticks.append(tick)
	return ticks


## Tick zakończenia przebiegu albo -1, gdy incydent jeszcze trwa.
func terminal_tick() -> int:
	return _simulation.get_tick() if _simulation.is_finished() else -1


## Widok i HUD czytają wyłącznie snapshot oraz kopię logu.
func _render() -> void:
	var snapshot := _simulation.get_state_snapshot()
	var notable := notable_events()
	_level_view.render(snapshot, highlight_cells())
	_timeline.render(snapshot, timeline_event_ticks(), terminal_tick())
	_hud.render(
		snapshot,
		_simulation.get_last_events(Hud.LOG_LINES),
		{
			"notable_events": notable,
			"running": _running,
			"finished": _simulation.is_finished(),
			"overlay_visible": _overlay_visible,
			"log_visible": _log_visible,
			"variant_index": int(_variant),
			"variant_name": current_variant_name(),
			"speed_index": _speed_index,
			"speed_multiplier": playback_speed(),
			"speed_label": playback_speed_label(),
		})
