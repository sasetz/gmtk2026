class_name SceneController
extends Control
## The one node that owns which top-level scene is on screen and the overlays on
## top of it. It listens to the EventBus (switch_scene / switch_overlay /
## toggle_pause) instead of being called directly, so any UI element or manager
## can request a change. The scenes themselves handle their own inner state.

enum Scene { MAIN_MENU, ROUND, SHOP }
enum State { DEFAULT, WON, LOST }

@export var menu_scene: PackedScene
@export var round_scene: PackedScene
@export var shop_scene: PackedScene
@export var options_scene: PackedScene
@export var credits_scene: PackedScene
@export var pause_scene: PackedScene

@onready var _screen: Control = $Screen
@onready var _hud: Control = $HUD
@onready var _overlays: Control = $Overlays
@onready var _result: Panel = $Result
@onready var _result_title: Label = $Result/Box/Title
@onready var _result_sub: Label = $Result/Box/Sub
@onready var _result_again: Button = $Result/Box/Again

var _current: Scene = Scene.MAIN_MENU
var _overlay: Control = null   # options / credits
var _pause: Control = null


func _ready() -> void:
	EventBus.switch_scene.connect(_select_scene)
	EventBus.switch_overlay.connect(_select_overlay)
	EventBus.toggle_pause.connect(_toggle_pause)
	_select_scene(Scene.MAIN_MENU)


# --- scenes -----------------------------------------------------------------

func _select_scene(scene: Scene) -> void:
	_set_paused(false)
	_close_overlay()
	_close_pause()
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
			Audio.play_music(&"menu")
		Scene.ROUND:
			_hud.visible = true
			_screen.add_child(round_scene.instantiate())
			Audio.play_music(&"round")
		Scene.SHOP:
			# The shop is a takeover with its own money readout, so hide the HUD.
			_hud.visible = false
			var shop: Control = shop_scene.instantiate()
			shop.continue_pressed.connect(func() -> void: EventBus.shop_left.emit())
			_screen.add_child(shop)
			Audio.play_music(&"shop")


# --- result (win / lose) ----------------------------------------------------

func _select_overlay(state: State) -> void:
	match state:
		State.DEFAULT:
			_result.visible = false
		State.WON:
			_show_result("YOU BEAT THE LAP", "Nicely timed.")
		State.LOST:
			_show_result("GAME OVER", "Ran out of score.")


func _show_result(title: String, sub: String) -> void:
	_hud.visible = false
	_result_title.text = title
	_result_sub.text = sub
	_result.visible = true
	_result_again.grab_focus()


func _on_again_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	RunManager.start_run()


func _on_menu_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	RunManager.end_run()
	_select_scene(Scene.MAIN_MENU)


# --- overlays (options / credits) -------------------------------------------

func _open_options() -> void:
	_push_overlay(options_scene)


func _open_credits() -> void:
	_push_overlay(credits_scene)


func _push_overlay(scene: PackedScene) -> void:
	if _overlay != null or scene == null:
		return
	_overlay = scene.instantiate()
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
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
