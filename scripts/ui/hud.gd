## HUD L0: wybór wariantu incydentu, tempo podglądu, stan symulacji, komunikat
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
## Prośba o przełączenie wariantu incydentu. Decyzję podejmuje koordynator.
signal variant_requested(variant_index: int)
## Prośba o zmianę tempa podglądu. Zmiany dokonuje koordynator.
signal speed_requested(speed_index: int)
## Prośba o cofnięcie lub wykonanie jednego ticka.
signal step_back_requested
signal step_forward_requested

## Ile ostatnich zdarzeń pokazuje panel. Wartość wynika z dostępnej wysokości:
## nagłówek, pusty wiersz i 11 wpisów mieszczą się w słupku HUD przy 1280 × 800.
const LOG_LINES := 11

## Panel zdarzeń ma własny, mniejszy rozmiar czcionki. Najdłuższy wiersz to
## 70 znaków — powód `intruder_visible_consecutive_ticks` pochodzi z rdzenia
## i nie wolno go skracać, więc to rozmiar musi ustąpić, nie treść.
const LOG_FONT_SIZE := 13

## Komunikat końcowy to najważniejszy tekst na ekranie, a podtytuł scenariusza
## renderował się od niego większą i jaśniejszą czcionką. Rozmiary przywracają
## hierarchię: nagłówek wyżej, podpis wyraźnie niżej.
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

const COLOR_DETECTED := Color(0.95, 0.35, 0.30, 1.0)
const COLOR_SUCCESS := Color(0.45, 0.88, 0.50, 1.0)
const COLOR_TICK_LIMIT := Color(0.98, 0.72, 0.25, 1.0)
const COLOR_NEUTRAL := Color(0.82, 0.84, 0.88, 1.0)

## Wiersze mieszczą się w 640 px przy czcionce 16 px o stałej szerokości
## (ok. 9,7 px na znak), czyli maksymalnie 65 znaków. Dłuższy wiersz rozepchnąłby
## etykietę poza prawą krawędź viewportu.
const LEGEND := """Sterowanie
  1 2 3  wariant       [ ]  tempo       Spacja  start / pauza
  , .  krok wstecz / naprzód      N  tick      R  restart
  Home End  początek / koniec     klik w oś czasu  przewiń
  F  stożki      L  panel zdarzeń      Esc  pauza"""

@onready var _scenario_label: Label = $ScenarioLabel
@onready var _detection_button: Button = $DetectionButton
@onready var _success_button: Button = $SuccessButton
@onready var _tick_limit_button: Button = $TickLimitButton
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

var _variant_buttons: Array[Button] = []
var _speed_buttons: Array[Button] = []

var _variant_titles: Array[String] = ["Wykrycie [1]", "Sukces [2]", "Limit ticków [3]"]
var _speed_titles: Array[String] = ["Wolno 0,5×", "Normalnie 1×", "Szybko 2×"]


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	_pause_button.pressed.connect(func() -> void: pause_toggle_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_step_back_button.pressed.connect(func() -> void: step_back_requested.emit())
	_step_forward_button.pressed.connect(func() -> void: step_forward_requested.emit())

	_variant_buttons = [_detection_button, _success_button, _tick_limit_button]
	for index in _variant_buttons.size():
		var variant := index
		_variant_buttons[index].pressed.connect(
			func() -> void: variant_requested.emit(variant))

	_speed_buttons = [_slow_button, _normal_button, _fast_button]
	for index in _speed_buttons.size():
		var speed := index
		_speed_buttons[index].pressed.connect(
			func() -> void: speed_requested.emit(speed))

	_scenario_label.text = "Scenariusz — te same reguły L0, inne dane wejściowe"
	_legend_label.text = LEGEND
	_apply_monospace_font()


## [param ui_state] zawiera flagi prezentacji: running, finished,
## overlay_visible, log_visible, variant_index, variant_name, speed_index,
## speed_multiplier, speed_label.
func render(snapshot: Dictionary, events: Array[Dictionary], ui_state: Dictionary) -> void:
	var running := bool(ui_state["running"])
	var finished := bool(ui_state["finished"])
	var log_visible := bool(ui_state["log_visible"])
	var status := STATUS_FINISHED if finished else (STATUS_RUNNING if running else STATUS_PAUSED)

	_render_marked_buttons(_variant_buttons, _variant_titles, int(ui_state["variant_index"]))
	_render_marked_buttons(_speed_buttons, _speed_titles, int(ui_state["speed_index"]))

	_start_button.disabled = running or finished
	_pause_button.disabled = finished
	_pause_button.text = "Pauza" if running else "Wznów"
	_step_back_button.disabled = int(snapshot["tick"]) <= 0
	_step_forward_button.disabled = finished

	_status_label.text = "\n".join(PackedStringArray([
		"SCENARIUSZ: %s" % String(ui_state["variant_name"]),
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
		"stożki: %s     panel zdarzeń: %s" % [
			"widoczne" if bool(ui_state["overlay_visible"]) else "ukryte",
			"widoczny" if log_visible else "ukryty",
		],
	]))

	_render_outcome(String(snapshot["outcome"]), int(snapshot["tick"]))
	_render_log(events, log_visible, ui_state["notable_events"] as Array[Dictionary])


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


## Komunikat końcowy: czerwony dla wykrycia, zielony dla sukcesu,
## pomarańczowy dla wyczerpania limitu ticków. Po zmianie wariantu wraca
## natychmiast do stanu neutralnego, bo snapshot ma wtedy outcome NONE.
func _render_outcome(outcome: String, tick: int) -> void:
	match outcome:
		SimulationState.OUTCOME_INTRUDER_DETECTED:
			_outcome_label.text = "INTRUZ WYKRYTY  —  tick %d" % tick
			_set_outcome_color(COLOR_DETECTED)
		SimulationState.OUTCOME_INTRUDER_SUCCESS:
			_outcome_label.text = "INTRUZ DOTARŁ DO CELU  —  tick %d" % tick
			_set_outcome_color(COLOR_SUCCESS)
		SimulationState.OUTCOME_TICK_LIMIT:
			_outcome_label.text = "LIMIT TICKÓW WYCZERPANY  —  tick %d" % tick
			_set_outcome_color(COLOR_TICK_LIMIT)
		_:
			_outcome_label.text = "incydent w toku"
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

	var lines := PackedStringArray(["event log  (tick | podmiot | zdarzenie | powód)", ""])
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


func _cell_text(cell: Vector2i) -> String:
	return "(%2d,%2d)" % [cell.x, cell.y]
