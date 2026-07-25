class_name SceneSelector
extends Control

@export var MainMenuScene: PackedScene
@export var RoundScene: PackedScene
@export var ShopScene: PackedScene

@onready var Overlay = $Overlay
@onready var OverlayTitle = $Overlay/Box/Title
@onready var OverlaySubtitle = $Overlay/Box/Sub

@onready var HUD = $HUD

enum Scene {
	MAIN_MENU,
	ROUND,
	SHOP,
}

enum State {
	DEFAULT,
	WON,
	LOST,
}

var current_node: Node

func _ready() -> void:
	EventBus.switch_scene.connect(_select_scene)
	EventBus.switch_overlay.connect(_select_overlay)
	EventBus.pause.connect(_toggle_pause)


func _select_scene(new_scene: Scene) -> void:
	if is_instance_valid(current_node):
		current_node.queue_free()
	var packed_scene := MainMenuScene
	match new_scene:
		Scene.MAIN_MENU:
			HUD.hide()
			packed_scene = MainMenuScene
		Scene.ROUND:
			HUD.show()
			packed_scene = RoundScene
		Scene.SHOP:
			HUD.show()
			packed_scene = ShopScene
	current_node = packed_scene.instantiate()
	add_child(current_node)

func _select_overlay(new_overlay: State) -> void:
	match new_overlay:
		State.DEFAULT:
			Overlay.hide()
		State.WON:
			OverlayTitle.text = "You WON!"
			OverlaySubtitle.text = "Press [Space] to continue"
			Overlay.show()
		State.LOST:
			OverlayTitle.text = "You LOST"
			OverlaySubtitle.text = "Press [Space] to restart"
			Overlay.show()

func _toggle_pause(pause: bool) -> void:
	pass
