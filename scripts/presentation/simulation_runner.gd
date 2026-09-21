## Koordynator sceny L0: adapter czasu, obsługa wejścia i odświeżanie widoku.
##
## Timer jest wyłącznie tempem wizualnym — nie jest zegarem domenowym.
## Każdy timeout wywołuje najwyżej jeden jawny step(). Jitter Timera nie może
## zmienić wyniku logicznego, bo rdzeń nie widzi delty ani czasu rzeczywistego.
##
## Ten node czyta input i steruje prezentacją. Nie zna reguł gry: wszystkie
## decyzje o wyniku, ruchu i wykryciu podejmuje rdzeń.
extends Node2D

@onready var _level_view: LevelView = $LevelL0
@onready var _hud: Hud = $HudLayer/Hud
@onready var _step_timer: Timer = $StepTimer

var _simulation: Simulation = null
var _running := false
var _overlay_visible := true
var _log_visible := true


func _ready() -> void:
	_simulation = Simulation.new()
	_simulation.initialize(ScenarioL0.create())

	_step_timer.wait_time = Simulation.SECONDS_PER_TICK
	_step_timer.one_shot = false
	_step_timer.timeout.connect(_on_step_timeout)

	_hud.start_requested.connect(_on_start_requested)
	_hud.pause_toggle_requested.connect(_on_pause_toggle_requested)
	_hud.restart_requested.connect(_on_restart_requested)

	_level_view.set_overlay_visible(_overlay_visible)
	_render()


## Sterowanie klawiaturą. Wejście należy wyłącznie do warstwy prezentacji —
## rdzeń nigdy go nie widzi.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	var key_event := event as InputEventKey
	match key_event.keycode:
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


## Restart przywraca rdzeń do identycznego stanu początkowego na świeżym
## scenariuszu i czyści stan prezentacji.
func _on_restart_requested() -> void:
	_stop()
	_simulation = Simulation.new()
	_simulation.initialize(ScenarioL0.create())
	_overlay_visible = true
	_log_visible = true
	_level_view.set_overlay_visible(_overlay_visible)
	_render()


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
		_log_visible)
