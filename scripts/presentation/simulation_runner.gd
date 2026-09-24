## Koordynator sceny: fazy PLAN i RUN, adapter czasu, obsługa wejścia
## i odświeżanie widoku.
##
## **PLAN** — gracz ustawia patrol i kamerę w edytorze (`PlanEditor`), który
## trzyma roboczą kopię danych scenariusza (draft). Plansza pokazuje draft:
## waypointy, kamerę, oba stożki w pozycji startowej i całą trasę intruza.
## **RUN** — deterministyczna noc na kopii draftu. Z RUN w każdej chwili wracamy
## do PLAN z tym samym draftem.
##
## Rdzeń dostaje draft wyłącznie przez `initialize()`. Prezentacja nigdy nie
## pisze do stanu `Simulation` — decyzja: `docs/DECISIONS.md`, 2026-09-24.
##
## Timer jest wyłącznie tempem wizualnym — nie jest zegarem domenowym.
## Każdy timeout wywołuje najwyżej jeden jawny step(). Jitter Timera nie może
## zmienić wyniku logicznego, bo rdzeń nie widzi delty ani czasu rzeczywistego.
extends Node2D

enum Phase {
	PLAN,
	RUN,
}

const PHASE_NAMES := {
	Phase.PLAN: Hud.PHASE_PLAN,
	Phase.RUN: Hud.PHASE_RUN,
}

## Jak długo HUD pokazuje komunikat odrzuconej edycji.
const REJECT_MESSAGE_SECONDS := 2.0

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
@onready var _plan_editor: PlanEditor = $PlanEditor
@onready var _timeline: TimelineView = $Timeline
@onready var _hud: Hud = $HudLayer/Hud
@onready var _step_timer: Timer = $StepTimer
@onready var _message_timer: Timer = $MessageTimer

var _phase: Phase = Phase.PLAN
## Dane bieżącej nocy: kopia draftu z chwili uruchomienia. Przewijanie i restart
## odtwarzają noc z tych danych, więc edycja draftu nie może ich zmienić.
var _run_scenario: ScenarioL0 = null
var _simulation: Simulation = null
var _plan_message := ""
var _speed_index := DEFAULT_SPEED_INDEX
var _running := false
var _overlay_visible := true
var _log_visible := true


func _ready() -> void:
	_step_timer.one_shot = false
	_step_timer.timeout.connect(_on_step_timeout)
	_apply_speed()

	_message_timer.one_shot = true
	_message_timer.wait_time = REJECT_MESSAGE_SECONDS
	_message_timer.timeout.connect(_clear_plan_message)

	_hud.start_requested.connect(_on_start_requested)
	_hud.pause_toggle_requested.connect(_on_pause_toggle_requested)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.speed_requested.connect(select_speed_index)
	_hud.step_back_requested.connect(step_back)
	_hud.step_forward_requested.connect(single_step)
	_hud.run_requested.connect(start_run)
	_hud.plan_requested.connect(return_to_plan)
	_hud.default_plan_requested.connect(reset_plan)

	# Edytor leży dokładnie na planszy: komórka (x, y) to ten sam piksel.
	_plan_editor.position = _level_view.position
	_plan_editor.draft_changed.connect(_on_draft_changed)
	_plan_editor.edit_rejected.connect(_on_edit_rejected)

	_level_view.set_overlay_visible(_overlay_visible)
	_render()


## Sterowanie klawiaturą i myszą. Wejście należy wyłącznie do warstwy
## prezentacji — rdzeń nigdy go nie widzi.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	var keycode := (event as InputEventKey).keycode
	var handled := _handle_plan_key(keycode) if _phase == Phase.PLAN else _handle_run_key(keycode)
	if handled:
		get_viewport().set_input_as_handled()


## Klawisze wspólne dla obu faz: tempo, stożki, panel zdarzeń.
func _handle_common_key(keycode: Key) -> bool:
	match keycode:
		KEY_F:
			toggle_overlay()
		KEY_L:
			toggle_log()
		KEY_BRACKETLEFT:
			step_speed(-1)
		KEY_BRACKETRIGHT:
			step_speed(1)
		_:
			return false
	return true


func _handle_plan_key(keycode: Key) -> bool:
	match keycode:
		KEY_SPACE:
			start_run()
		KEY_R:
			reset_plan()
		_:
			return _handle_common_key(keycode)
	return true


func _handle_run_key(keycode: Key) -> bool:
	match keycode:
		KEY_SPACE:
			_on_pause_toggle_requested()
		KEY_N, KEY_PERIOD:
			single_step()
		KEY_COMMA:
			step_back()
		KEY_R:
			_on_restart_requested()
		KEY_P:
			return_to_plan()
		KEY_HOME:
			seek_to_tick(0)
		KEY_END:
			seek_to_end()
		KEY_ESCAPE:
			pause()
		_:
			return _handle_common_key(keycode)
	return true


## PLAN: przeciąganie po planszy. RUN: kliknięcie w oś czasu przewija przebieg.
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _phase == Phase.PLAN:
		var cell := _plan_editor.cell_at_global_point(event.global_position)
		if event.pressed:
			if not _plan_editor.begin_drag(cell):
				return
		elif _plan_editor.is_dragging():
			_plan_editor.drag_to(cell)
			_plan_editor.end_drag()
		else:
			return
		get_viewport().set_input_as_handled()
		return

	if not event.pressed:
		return
	if not _timeline.contains_global_point(event.global_position):
		return
	seek_to_tick(_timeline.tick_at_global_point(event.global_position))
	get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _phase != Phase.PLAN or not _plan_editor.is_dragging():
		return
	_plan_editor.drag_to(_plan_editor.cell_at_global_point(event.global_position))
	get_viewport().set_input_as_handled()


# === fazy PLAN i RUN ==========================================================

func current_phase() -> Phase:
	return _phase


func current_phase_name() -> String:
	return String(PHASE_NAMES[_phase])


## Uruchomienie nocy: kopia draftu trafia do świeżej `Simulation` przez
## `initialize()` i przebieg od razu rusza — gracz nie musi niczego dociskać.
func start_run() -> void:
	if _phase == Phase.RUN:
		return
	_plan_editor.cancel_drag()
	_clear_plan_message()
	_run_scenario = _plan_editor.draft()
	_phase = Phase.RUN
	seek_to_tick(0)
	_on_start_requested()


## Powrót do planowania z tym samym draftem — z wyniku terminalnego albo
## w trakcie nocy. Ostatnia symulacja jest porzucana, nie wznawiana.
func return_to_plan() -> void:
	if _phase == Phase.PLAN:
		return
	_stop()
	_phase = Phase.PLAN
	_render()


## Klawisz R w fazie planowania: plan domyślny zagadki.
func reset_plan() -> void:
	if _phase != Phase.PLAN:
		return
	_plan_editor.reset_to_puzzle()


func plan_message() -> String:
	return _plan_message


## Podgląd planu: osobna, nigdy nie krokowana `Simulation` zainicjalizowana
## kopią draftu. Widok czyta z niej snapshot dokładnie tak samo jak w nocy,
## więc plansza pokazuje to, co rdzeń naprawdę dostanie na starcie.
func plan_preview_snapshot() -> Dictionary:
	var preview := Simulation.new()
	preview.initialize(_plan_editor.draft())
	return preview.get_state_snapshot()


## Zmiana draftu przerysowuje podgląd tylko w fazie planowania. Trwająca noc
## pracuje na własnej kopii danych i nie może jej zobaczyć.
func _on_draft_changed() -> void:
	if _phase != Phase.PLAN:
		return
	_clear_plan_message()


func _on_edit_rejected(message: String) -> void:
	_plan_message = message
	_message_timer.start()
	_render()


func _clear_plan_message() -> void:
	_plan_message = ""
	_message_timer.stop()
	_render()


# === tempo automatycznego przebiegu ===========================================

## Zmiana tempa o jeden stopień: -1 wolniej, +1 szybciej. Na krańcach zostaje
## przy skrajnej wartości. Nie rusza ticka, logu, planu ani stanu auto-run.
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


# === przewijanie nocy =========================================================

## Przewinięcie przebiegu do wskazanego ticka.
##
## Działa **dzięki determinizmowi rdzenia**: nie ma cofania stanu ani historii
## snapshotów — budujemy świeżą symulację na tych samych danych nocy i wykonujemy
## dokładnie [param target] kroków. Ten sam scenariusz zawsze daje ten sam
## przebieg, więc odtworzony tick jest identyczny z oryginalnym.
##
## Przewijanie zatrzymuje automatyczny przebieg i zachowuje plan oraz tempo.
func seek_to_tick(target: int) -> void:
	if _phase != Phase.RUN:
		return
	_stop()
	_simulation = Simulation.new()
	_simulation.initialize(_run_scenario)
	for i in range(maxi(0, target)):
		if _simulation.is_finished():
			break
		_simulation.step()
	_render()


## Przewinięcie do końca przebiegu. Pętla w [method seek_to_tick] i tak kończy
## się na stanie terminalnym, więc limit scenariusza jest tu tylko górną granicą.
func seek_to_end() -> void:
	if _phase != Phase.RUN:
		return
	seek_to_tick(int(_simulation.get_state_snapshot()["max_ticks"]))


## Cofnięcie o jeden tick. Na ticku 0 nie robi nic.
func step_back() -> void:
	if _phase != Phase.RUN:
		return
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
	if _phase != Phase.RUN:
		return
	if _simulation.is_finished():
		_stop()
		_render()
		return

	_simulation.step()

	if _simulation.is_finished():
		_stop()
	_render()


func _on_start_requested() -> void:
	if _phase != Phase.RUN or _simulation.is_finished() or _running:
		return
	_running = true
	_step_timer.start()
	_render()


func _on_pause_toggle_requested() -> void:
	if _phase != Phase.RUN or _simulation.is_finished():
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


## Restart nocy na tym samym planie: świeża symulacja, tick 0, pauza.
func _on_restart_requested() -> void:
	seek_to_tick(0)


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
	var notable: Array[Dictionary] = []
	if _phase != Phase.RUN:
		return notable
	var tick := _simulation.get_tick()
	for entry: Dictionary in _simulation.get_last_events(Hud.LOG_LINES):
		if int(entry["tick"]) == tick and String(entry["event"]) != ROUTINE_EVENT:
			notable.append(entry)
	return notable


## Komórki podmiotów, których dotyczą zdarzenia bieżącego ticka.
## Dzięki temu tester widzi na planszy dokładnie to, co czyta w logu.
func highlight_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _phase != Phase.RUN:
		return cells
	var snapshot := _simulation.get_state_snapshot()
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
	if _phase != Phase.RUN:
		return ticks
	for entry: Dictionary in _simulation.get_event_log():
		if String(entry["event"]) == ROUTINE_EVENT:
			continue
		var tick := int(entry["tick"])
		if not ticks.has(tick):
			ticks.append(tick)
	return ticks


## Tick zakończenia przebiegu albo -1, gdy noc jeszcze trwa albo trwa planowanie.
func terminal_tick() -> int:
	if _phase != Phase.RUN or not _simulation.is_finished():
		return -1
	return _simulation.get_tick()


## Widok i HUD czytają wyłącznie snapshot oraz kopię logu. W fazie planowania
## snapshot pochodzi z podglądu draftu, a log jest pusty.
func _render() -> void:
	var planning := _phase == Phase.PLAN
	var snapshot := plan_preview_snapshot() if planning else _simulation.get_state_snapshot()
	var events: Array[Dictionary] = []
	if not planning:
		events = _simulation.get_last_events(Hud.LOG_LINES)

	_plan_editor.visible = planning
	# W planowaniu nie ma przebiegu do przewijania — oś czasu wraca w nocy.
	_timeline.visible = not planning
	_level_view.render(snapshot, highlight_cells())
	_timeline.render(snapshot, timeline_event_ticks(), terminal_tick())
	_hud.render(
		snapshot,
		events,
		{
			"phase": current_phase_name(),
			"plan_message": _plan_message,
			"notable_events": notable_events(),
			"running": _running,
			"finished": not planning and _simulation.is_finished(),
			"overlay_visible": _overlay_visible,
			"log_visible": _log_visible,
			"speed_index": _speed_index,
			"speed_multiplier": playback_speed(),
			"speed_label": playback_speed_label(),
		})
