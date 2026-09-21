## HUD L0: stan symulacji, komunikat końcowy, panel zdarzeń i legenda sterowania.
##
## HUD nie zna FSM ani ticków — wyłącznie wyświetla to, co dostanie ze snapshotu,
## i zgłasza intencję użytkownika sygnałem. Nigdy nie zmienia stanu rdzenia
## i nigdy nie mutuje event logu (dostaje jego kopię).
class_name Hud
extends Control

signal start_requested
signal pause_toggle_requested
signal restart_requested

## Ile ostatnich zdarzeń pokazuje panel.
const LOG_LINES := 12

const STATUS_RUNNING := "RUNNING"
const STATUS_PAUSED := "PAUSED"
const STATUS_FINISHED := "FINISHED"

const COLOR_DETECTED := Color(0.95, 0.35, 0.30, 1.0)
const COLOR_SUCCESS := Color(0.45, 0.88, 0.50, 1.0)
const COLOR_TICK_LIMIT := Color(0.98, 0.72, 0.25, 1.0)
const COLOR_NEUTRAL := Color(0.82, 0.84, 0.88, 1.0)

const LEGEND := """Sterowanie
  Spacja  start / pauza
  N       jeden tick
  R       restart
  F       stożki widzenia
  L       panel zdarzeń
  Esc     pauza"""

@onready var _start_button: Button = $StartButton
@onready var _pause_button: Button = $PauseButton
@onready var _restart_button: Button = $RestartButton
@onready var _status_label: Label = $StatusLabel
@onready var _outcome_label: Label = $OutcomeLabel
@onready var _legend_label: Label = $LegendLabel
@onready var _log_label: Label = $LogLabel


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	_pause_button.pressed.connect(func() -> void: pause_toggle_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_legend_label.text = LEGEND


func render(
		snapshot: Dictionary,
		events: Array[Dictionary],
		running: bool,
		finished: bool,
		overlay_visible: bool,
		log_visible: bool) -> void:
	var status := STATUS_FINISHED if finished else (STATUS_RUNNING if running else STATUS_PAUSED)

	_start_button.disabled = running or finished
	_pause_button.disabled = finished
	_pause_button.text = "Pauza" if running else "Wznów"

	_status_label.text = "\n".join(PackedStringArray([
		"OBIEKT '84 — incydent L0",
		"",
		"status:    %s" % status,
		"tick:      %d / %d   (10 Hz)" % [int(snapshot["tick"]), int(snapshot["max_ticks"])],
		"",
		"strażnik:  %-9s %s  wp=%d  widzi=%d" % [
			String(snapshot["guard_state"]),
			_cell_text(snapshot["guard_position"]),
			int(snapshot["guard_waypoint_index"]),
			int(snapshot["guard_visible_streak"]),
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
		"stożki:    %s        panel zdarzeń: %s" % [
			"widoczne" if overlay_visible else "ukryte",
			"widoczny" if log_visible else "ukryty",
		],
	]))

	_render_outcome(String(snapshot["outcome"]), int(snapshot["tick"]))
	_render_log(events, log_visible)


## Komunikat końcowy: czerwony dla wykrycia, zielony dla sukcesu,
## pomarańczowy dla wyczerpania limitu ticków.
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


func _render_log(events: Array[Dictionary], log_visible: bool) -> void:
	_log_label.visible = log_visible
	if not log_visible:
		return

	var lines := PackedStringArray(["event log  (tick | podmiot | zdarzenie | powód)", ""])
	if events.is_empty():
		lines.append("  — brak zdarzeń —")
	for entry: Dictionary in events:
		lines.append("  %3d  %-12s %-18s %s" % [
			int(entry["tick"]),
			String(entry["subject"]),
			String(entry["event"]),
			String(entry["reason"]),
		])
	_log_label.text = "\n".join(lines)


func _cell_text(cell: Vector2i) -> String:
	return "(%2d,%2d)" % [cell.x, cell.y]
