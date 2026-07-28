class_name SceneController
extends Control
## The one node that owns which top-level scene is on screen and the overlays on
## top of it. It listens to the EventBus (switch_scene / round_result /
## toggle_pause) instead of being called directly, so any UI element or manager
## can request a change. The scenes themselves handle their own inner state.

enum Scene { MAIN_MENU, ROUND, SHOP }

## Pause and the menus always sit above the board. The round lifts whatever the
## tutorial is pointing at (see Round.HIGHLIGHT_Z), and without this the pause
## menu came up behind the stopwatches.
const OVERLAY_Z: int = 500

@export var menu_scene: PackedScene
@export var round_scene: PackedScene
@export var shop_scene: PackedScene
@export var options_scene: PackedScene
@export var credits_scene: PackedScene
@export var pause_scene: PackedScene
@export var tutorial_scene: PackedScene

@onready var _screen: Control = $Screen
@onready var _hud: Control = $HUD
@onready var _overlays: Control = $Overlays
@onready var _result: Panel = $Result
@onready var _result_title: Label = $Result/Box/Title
@onready var _result_sub: Label = $Result/Box/Sub
@onready var _result_continue: PushButton = $Result/Continue

var _current: Scene = Scene.MAIN_MENU
var _overlay: Control = null   # options / credits
var _pause: Control = null
var _tutorial: Control = null
var _pending_won: bool = false


func _ready() -> void:
	EventBus.switch_scene.connect(_select_scene)
	EventBus.round_result.connect(_on_round_result)
	EventBus.toggle_pause.connect(_toggle_pause)
	EventBus.tutorial_finished.connect(_close_tutorial)
	# The cat button sounds itself; the corner cog is a plain click.
	UiSound.play_on($OptionsCorner, &"ui_click")
	_select_scene(Scene.MAIN_MENU)


# --- tutorial ---------------------------------------------------------------

## The tutorial overlay rides along with the round screen for the scripted lap.
func _sync_tutorial() -> void:
	var wanted: bool = Tutorial.active and _current == Scene.ROUND
	if wanted and _tutorial == null and tutorial_scene != null:
		_tutorial = tutorial_scene.instantiate()
		_overlays.add_child(_tutorial)
	elif not wanted:
		_close_tutorial()


func _close_tutorial() -> void:
	if _tutorial != null:
		# Out of the tree at once: a queued-but-still-parented overlay would
		# double up on the event bus with the one replacing it.
		_overlays.remove_child(_tutorial)
		_tutorial.queue_free()
		_tutorial = null


# --- scenes -----------------------------------------------------------------

func _select_scene(scene: Scene) -> void:
	_set_paused(false)
	_close_overlay()
	_close_pause()
	_close_tutorial()
	_result.visible = false
	_current = scene
	for c: Node in _screen.get_children():
		c.queue_free()
	match scene:
		Scene.MAIN_MENU:
			_hud.visible = false
			var menu: Control = menu_scene.instantiate()
			menu.play_pressed.connect(RunManager.start_run)
			menu.options_pressed.connect(_open_options)
			menu.credits_pressed.connect(_open_credits)
			menu.quit_pressed.connect(func() -> void: get_tree().quit())
			_screen.add_child(menu)
			Audio.play_music(&"Normal")
		Scene.ROUND:
			_hud.visible = true
			_screen.add_child(round_scene.instantiate())
			Audio.play_round_music()
			_sync_tutorial()
		Scene.SHOP:
			_hud.visible = true
			var shop: Control = shop_scene.instantiate()
			shop.continue_pressed.connect(func() -> void: EventBus.shop_left.emit())
			_screen.add_child(shop)
			Audio.play_music(&"Shop")


# --- round result (gated behind Continue) -----------------------------------

func _on_round_result(won: bool, is_boss: bool, reward: int) -> void:
	_pending_won = won
	_hud.visible = true
	if won:
		_result_title.text = "BOSS DEFEATED" if is_boss else "ROUND CLEARED"
		_result_sub.text = "+$%d banked" % reward
	else:
		_result_title.text = "GAME OVER"
		_result_sub.text = "You ran out of score."
	_result.visible = true
	_result_continue.grab_focus()


func _on_continue_pressed() -> void:
	RunManager.continue_from_result(_pending_won)


# --- overlays (options / credits) -------------------------------------------

## The always-visible corner button opens options (unless something is already up).
func _on_options_corner_pressed() -> void:
	if _overlay == null and _pause == null:
		_open_options()


func _open_options() -> void:
	_push_overlay(options_scene)
	if _overlay != null and _overlay.has_signal("credits_requested"):
		_overlay.credits_requested.connect(_options_to_credits)


func _open_credits() -> void:
	_push_overlay(credits_scene)


## Options -> Credits: swap one overlay for the other.
func _options_to_credits() -> void:
	_close_overlay()
	_open_credits()


func _push_overlay(scene: PackedScene) -> void:
	if _overlay != null or scene == null:
		return
	_overlay = scene.instantiate()
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.z_index = OVERLAY_Z
	_overlay.closed.connect(_close_overlay)
	_overlays.add_child(_overlay)


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


# --- pause ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"cancel"):
		return
	if _overlay != null or not _in_run():
		return
	get_viewport().set_input_as_handled()
	EventBus.toggle_pause.emit()


func _in_run() -> bool:
	return not _result.visible and (_current == Scene.ROUND or _current == Scene.SHOP)


func _toggle_pause() -> void:
	if _pause == null:
		if _in_run():
			_open_pause()
	else:
		_close_pause()


func _open_pause() -> void:
	_set_paused(true)
	_pause = pause_scene.instantiate()
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.z_index = OVERLAY_Z
	_pause.resume_pressed.connect(_close_pause)
	_pause.options_pressed.connect(_open_options)
	_pause.menu_pressed.connect(_pause_to_menu)
	_overlays.add_child(_pause)


func _pause_to_menu() -> void:
	_close_pause()
	RunManager.end_run()
	_select_scene(Scene.MAIN_MENU)


func _close_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
	_set_paused(false)


func _set_paused(on: bool) -> void:
	get_tree().paused = on
