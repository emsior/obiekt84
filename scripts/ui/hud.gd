## HUD: faza planowania i nocy, tempo podglądu, stan symulacji, komunikat
## końcowy, panel zdarzeń i legenda sterowania.
##
## HUD jest pasywny. Nie zna FSM, ticków ani danych scenariusza — wyświetla to,
## co dostanie w `render()`, i zgłasza intencję użytkownika sygnałem.
## Nigdy nie dotyka `Simulation`, `ScenarioL0`, `SimulationState` ani `Timer`
## i nigdy nie mutuje event logu (dostaje jego kopię).
class_name Hud
extends Control

signal start_requested
signal pause_toggle_requested
signal restart_requested
## Prośba o zmianę tempa podglądu. Zmiany dokonuje koordynator.
signal speed_requested(speed_index: int)
## Prośba o cofnięcie lub wykonanie jednego ticka.
signal step_back_requested
signal step_forward_requested
## Prośby o przejście między fazami i o plan domyślny. Decyzję podejmuje koordynator.
signal run_requested
signal plan_requested
signal default_plan_requested

## Nazwy faz przekazywane w `ui_state["phase"]`.
const PHASE_PLAN := "PLAN"
const PHASE_RUN := "NOC"

## Ile ostatnich zdarzeń pokazuje panel. Wartość wynika z dostępnej wysokości:
## nagłówek i 10 wpisów (11 wierszy po ok. 19,8 px) mieszczą się w 234 px słupka
## HUD przy 1280 × 800. Incydenty L0 miały najwyżej 10 zdarzeń, więc dawny
## limit 11 wpisów z pustym wierszem nigdy się nie zapełnił — plan domyślny L1-A
## ma ich 13 i wypychał panel poza ekran.
const LOG_LINES := 10

## Panel zdarzeń ma własny, mniejszy rozmiar czcionki. Najdłuższy wiersz to
## 70 znaków — powód `intruder_visible_consecutive_ticks` pochodzi z rdzenia
## i nie wolno go skracać, więc to rozmiar musi ustąpić, nie treść.
const LOG_FONT_SIZE := 13

## Komunikat końcowy to najważniejszy tekst na ekranie, a podtytuł renderował
## się od niego większą i jaśniejszą czcionką. Rozmiary przywracają hierarchię:
## nagłówek wyżej, podpis wyraźnie niżej.
const OUTCOME_FONT_SIZE := 22
const SCENARIO_FONT_SIZE := 13
const COLOR_SUBTITLE := Color(0.55, 0.59, 0.66, 1.0)

const STATUS_RUNNING := "RUNNING"
const STATUS_PAUSED := "PAUSED"
const STATUS_FINISHED := "FINISHED"

const MARKER_ACTIVE := "● "
const MARKER_INACTIVE := "○ "
## Znacznik wpisu, który jest jednocześnie wyróżniony na planszy.
## Wariant bez wyróżnienia ma tę samą szerokość, żeby kolumny się nie rozjeżdżały.
const MARKER_EVENT := "►"
const MARKER_EVENT_NONE := " "

## Wynik oceniany z perspektywy obrońcy: wykrycie intruza to sukces gracza.
const COLOR_DEFENDED := Color(0.45, 0.88, 0.50, 1.0)
const COLOR_BREACHED := Color(0.95, 0.35, 0.30, 1.0)
const COLOR_TICK_LIMIT := Color(0.98, 0.72, 0.25, 1.0)
const COLOR_NEUTRAL := Color(0.82, 0.84, 0.88, 1.0)
## Komunikat odrzuconej edycji planu.
const COLOR_REJECTED := Color(0.95, 0.35, 0.30, 1.0)

const SUBTITLE_PLAN := "Faza planowania — ustaw patrol i kamerę, potem uruchom noc"
const SUBTITLE_RUN := "Noc — deterministyczny przebieg twojego planu"

## Nazwy kierunków kamery w panelu statusu.
const FACING_NAMES := {
	Vector2i.UP: "góra",
	Vector2i.RIGHT: "prawo",
	Vector2i.DOWN: "dół",
	Vector2i.LEFT: "lewo",
}

## Wiersze mieszczą się w 640 px przy czcionce 16 px o stałej szerokości
## (ok. 9,7 px na znak), czyli maksymalnie 65 znaków. Dłuższy wiersz rozepchnąłby
## etykietę poza prawą krawędź viewportu.
const LEGEND_PLAN := """Sterowanie — plan
  przeciągnij węzeł — patrol · przeciągnij kamerę — pozycja
  klik w kamerę — obrót · Spacja — uruchom noc
  R — plan domyślny      [ ]  tempo      F  stożki"""

const LEGEND_RUN := """Sterowanie — noc
  [ ]  tempo       Spacja  start / pauza      P  wróć do planu
  , .  krok wstecz / naprzód      N  tick      R  restart nocy
  Home End  początek / koniec     klik w oś czasu  przewiń
  F  stożki      L  panel zdarzeń      Esc  pauza"""

@onready var _scenario_label: Label = $ScenarioLabel
@onready var _run_button: Button = $RunButton
@onready var _plan_button: Button = $PlanButton
@onready var _default_plan_button: Button = $DefaultPlanButton
@onready var _slow_button: Button = $SlowButton
@onready var _normal_button: Button = $NormalButton
@onready var _fast_button: Button = $FastButton
@onready var _start_button: Button = $StartButton
@onready var _pause_button: Button = $PauseButton
@onready var _restart_button: Button = $RestartButton
@onready var _step_back_button: Button = $StepBackButton
@onready var _step_forward_button: Button = $StepForwardButton
@onready var _status_label: Label = $StatusLabel
@onready var _outcome_label: Label = $OutcomeLabel
@onready var _legend_label: Label = $LegendLabel
@onready var _log_label: Label = $LogLabel

var _speed_buttons: Array[Button] = []

var _speed_titles: Array[String] = ["Wolno 0,5×", "Normalnie 1×", "Szybko 2×"]


func _ready() -> void:
	# Pełnoekranowy korzeń HUD nie może łapać myszy — inaczej kliknięcia
	# i przeciągnięcia na planszy nie dotarłyby do koordynatora.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Przycisk z fokusem przechwyciłby Spację, która musi zawsze trafić do
	# koordynatora (uruchom noc / pauza). Przyciski obsługujemy myszą.
	for child in get_children():
		if child is Button:
			(child as Button).focus_mode = Control.FOCUS_NONE

	_start_button.pressed.connect(func() -> void: start_requested.emit())
	_pause_button.pressed.connect(func() -> void: pause_toggle_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_step_back_button.pressed.connect(func() -> void: step_back_requested.emit())
	_step_forward_button.pressed.connect(func() -> void: step_forward_requested.emit())
	_run_button.pressed.connect(func() -> void: run_requested.emit())
	_plan_button.pressed.connect(func() -> void: plan_requested.emit())
	_default_plan_button.pressed.connect(func() -> void: default_plan_requested.emit())

	_speed_buttons = [_slow_button, _normal_button, _fast_button]
	for index in _speed_buttons.size():
		var speed := index
		_speed_buttons[index].pressed.connect(
			func() -> void: speed_requested.emit(speed))

	_scenario_label.text = SUBTITLE_PLAN
	_scenario_label.clip_text = true
	_legend_label.text = LEGEND_PLAN
	_apply_monospace_font()


## [param ui_state] zawiera flagi prezentacji: phase, plan_message, running,
## finished, overlay_visible, log_visible, speed_index, speed_multiplier,
## speed_label, notable_events.
func render(snapshot: Dictionary, events: Array[Dictionary], ui_state: Dictionary) -> void:
	var planning := String(ui_state["phase"]) == PHASE_PLAN
	var running := bool(ui_state["running"])
	var finished := bool(ui_state["finished"])
	var log_visible := bool(ui_state["log_visible"])

	_render_marked_buttons(_speed_buttons, _speed_titles, int(ui_state["speed_index"]))

	_run_button.disabled = not planning
	_plan_button.disabled = planning
	_default_plan_button.disabled = not planning

	_start_button.disabled = planning or running or finished
	_pause_button.disabled = planning or finished
	_pause_button.text = "Pauza" if running else "Wznów"
	_restart_button.disabled = planning
	_step_back_button.disabled = planning or int(snapshot["tick"]) <= 0
	_step_forward_button.disabled = planning or finished

	_legend_label.text = LEGEND_PLAN if planning else LEGEND_RUN
	_render_subtitle(planning, String(ui_state["plan_message"]))

	if planning:
		_status_label.text = _plan_status_text(snapshot, ui_state)
		_outcome_label.text = "PLAN OBRONY"
		_set_outcome_color(COLOR_NEUTRAL)
	else:
		_status_label.text = _run_status_text(snapshot, ui_state, running, finished)
		_render_outcome(String(snapshot["outcome"]), int(snapshot["tick"]))
	_render_log(events, log_visible, ui_state["notable_events"] as Array[Dictionary])


## Panel statusu w fazie planowania: to, co gracz właśnie ustawia.
func _plan_status_text(snapshot: Dictionary, ui_state: Dictionary) -> String:
	var waypoints: Array = snapshot["guard_waypoints"]
	var patrol := PackedStringArray()
	for i in waypoints.size():
		patrol.append("W%d %s" % [i + 1, _cell_text(waypoints[i])])
	var route: Array = snapshot["intruder_route"]

	return "\n".join(PackedStringArray([
		"FAZA: PLAN — noc jeszcze się nie zaczęła",
		"",
		"patrol:    %s" % "  ".join(patrol),
		"strażnik:  start na W1   zasięg=%d" % int(snapshot["guard_view_range"]),
		"kamera:    %s  patrzy: %-5s  zasięg=%d" % [
			_cell_text(snapshot["camera_position"]),
			_facing_text(snapshot["camera_facing"]),
			int(snapshot["camera_range"]),
		],
		"intruz:    trasa %d komórek   cel %s" % [
			route.size(),
			_cell_text(route[route.size() - 1]),
		],
		"limit:     %d ticków   (10 Hz)" % int(snapshot["max_ticks"]),
		"tempo:     %s   [%s]" % [
			_speed_text(float(ui_state["speed_multiplier"])),
			String(ui_state["speed_label"]),
		],
		"",
		_toggles_text(ui_state),
	]))


func _run_status_text(
		snapshot: Dictionary,
		ui_state: Dictionary,
		running: bool,
		finished: bool) -> String:
	var status := STATUS_FINISHED if finished else (STATUS_RUNNING if running else STATUS_PAUSED)
	return "\n".join(PackedStringArray([
		"FAZA: NOC — przebieg twojego planu",
		"",
		"status:    %s" % status,
		"tick:      %d / %d   (10 Hz)" % [int(snapshot["tick"]), int(snapshot["max_ticks"])],
		"tempo:     %s   [%s]" % [
			_speed_text(float(ui_state["speed_multiplier"])),
			String(ui_state["speed_label"]),
		],
		"",
		"strażnik:  %-9s %s  wp=%d  widzi=%d  zasięg=%d" % [
			String(snapshot["guard_state"]),
			_cell_text(snapshot["guard_position"]),
			int(snapshot["guard_waypoint_index"]),
			int(snapshot["guard_visible_streak"]),
			int(snapshot["guard_view_range"]),
		],
		"intruz:    %-9s %s  krok=%d/%d" % [
			String(snapshot["intruder_state"]),
			_cell_text(snapshot["intruder_position"]),
			int(snapshot["intruder_route_index"]),
			(snapshot["intruder_route"] as Array).size() - 1,
		],
		"kamera:    %-9s %s  zasięg=%d" % [
			"STATIC",
			_cell_text(snapshot["camera_position"]),
			int(snapshot["camera_range"]),
		],
		"",
		_toggles_text(ui_state),
	]))


func _toggles_text(ui_state: Dictionary) -> String:
	return "stożki: %s     panel zdarzeń: %s" % [
		"widoczne" if bool(ui_state["overlay_visible"]) else "ukryte",
		"widoczny" if bool(ui_state["log_visible"]) else "ukryty",
	]


## Podtytuł mówi, w jakiej fazie jest gracz. W planowaniu przez 2 s zamienia się
## w czerwony komunikat odrzuconej edycji — pierwszy problem z `validate()`.
func _render_subtitle(planning: bool, plan_message: String) -> void:
	if planning and not plan_message.is_empty():
		_scenario_label.text = "Odrzucone: " + plan_message
		_scenario_label.add_theme_color_override("font_color", COLOR_REJECTED)
		return
	_scenario_label.text = SUBTITLE_PLAN if planning else SUBTITLE_RUN
	_scenario_label.add_theme_color_override("font_color", COLOR_SUBTITLE)


## Panel statusu, legenda i event log wyrównują kolumny spacjami, więc wymagają
## czcionki o stałej szerokości. Czcionka jest dołączona do repozytorium
## (`assets/fonts`, licencja w `LICENSE_DejaVu.txt`), bo `SystemFont` nie działa
## w eksporcie Web ani w kontenerze CI — tam cofał się do czcionki proporcjonalnej
## i kolumny się rozjeżdżały. Decyzja: `docs/DECISIONS.md`, 2026-09-23.
const MONOSPACE_FONT: Font = preload("res://assets/fonts/DejaVuSansMono.ttf")


func _apply_monospace_font() -> void:
	for label: Label in [_status_label, _legend_label, _log_label]:
		label.add_theme_font_override("font", MONOSPACE_FONT)
	_log_label.add_theme_font_size_override("font_size", LOG_FONT_SIZE)

	_outcome_label.add_theme_font_size_override("font_size", OUTCOME_FONT_SIZE)
	_scenario_label.add_theme_font_size_override("font_size", SCENARIO_FONT_SIZE)
	_scenario_label.add_theme_color_override("font_color", COLOR_SUBTITLE)


## Aktywna pozycja w grupie jest oznaczona wypełnionym znacznikiem.
func _render_marked_buttons(buttons: Array[Button], titles: Array[String], active: int) -> void:
	for index in buttons.size():
		var marker := MARKER_ACTIVE if index == active else MARKER_INACTIVE
		buttons[index].text = marker + titles[index]


## Komunikat końcowy z perspektywy obrońcy: zielony, gdy obiekt obroniony
## (intruz wykryty), czerwony, gdy intruz dotarł do celu, pomarańczowy przy
## wyczerpaniu limitu ticków. Po restarcie wraca do stanu neutralnego, bo
## snapshot ma wtedy outcome NONE.
func _render_outcome(outcome: String, tick: int) -> void:
	match outcome:
		SimulationState.OUTCOME_INTRUDER_DETECTED:
			_outcome_label.text = "OBIEKT ZABEZPIECZONY  —  tick %d" % tick
			_set_outcome_color(COLOR_DEFENDED)
		SimulationState.OUTCOME_INTRUDER_SUCCESS:
			_outcome_label.text = "DANE WYKRADZIONE  —  tick %d  ·  wróć do planu [P]" % tick
			_set_outcome_color(COLOR_BREACHED)
		SimulationState.OUTCOME_TICK_LIMIT:
			_outcome_label.text = "LIMIT TICKÓW WYCZERPANY  —  tick %d" % tick
			_set_outcome_color(COLOR_TICK_LIMIT)
		_:
			_outcome_label.text = "noc w toku"
			_set_outcome_color(COLOR_NEUTRAL)


func _set_outcome_color(color: Color) -> void:
	_outcome_label.add_theme_color_override("font_color", color)


## Wpisy z bieżącego ticka, które dostały wyróżnienie na planszy, są oznaczone
## strzałką — dzięki temu widać, że biały obrys na mapie i ten wiersz to to samo.
func _render_log(
		events: Array[Dictionary],
		log_visible: bool,
		notable: Array[Dictionary]) -> void:
	_log_label.visible = log_visible
	if not log_visible:
		return

	var lines := PackedStringArray(["event log  (tick | podmiot | zdarzenie | powód)"])
	if events.is_empty():
		lines.append("  — brak zdarzeń —")
	for entry: Dictionary in events:
		var marker := MARKER_EVENT if notable.has(entry) else MARKER_EVENT_NONE
		lines.append("%s %3d %-11s %-16s %s" % [
			marker,
			int(entry["tick"]),
			String(entry["subject"]),
			String(entry["event"]),
			String(entry["reason"]),
		])
	_log_label.text = "\n".join(lines)


## "0,5×" zamiast "0.5x" — spójnie z językiem interfejsu.
func _speed_text(multiplier: float) -> String:
	if is_equal_approx(multiplier, 0.5):
		return "0,5×"
	if is_equal_approx(multiplier, 2.0):
		return "2×"
	return "1×"


func _facing_text(facing: Vector2i) -> String:
	return String(FACING_NAMES.get(facing, "?"))


func _cell_text(cell: Vector2i) -> String:
	return "(%2d,%2d)" % [cell.x, cell.y]
