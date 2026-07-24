extends Control
## A short, skippable "how to play" shown when you hit Play.
##
## Paged rather than an interactive hand-holding round: the game's rules are
## about reading numbers, so a few clear screens beat a scripted round that has
## to fight the live clock. Skip is always one click away, and the last page
## drops you straight into the run.

const GameScene: String = "res://scenes/game.tscn"

const PAGES: Array[Dictionary] = [
	{
		"title": "The Countdown",
		"body": "A clock counts DOWN.\n\nPress SPACE (or click) once to START it — then press again to LOCK the time you see.\n\nYou get 4 locks per round. The clock never stops on its own, so every lock is a decision.",
	},
	{
		"title": "Score the Digits",
		"body": "A locked time scores on what its digits ARE:\n\n  ODD / EVEN  —  the last digit\n  ROUND  —  the decimals are zero  (03:0)\n  STRAIGHT  —  every digit the same  (05:5)\n  THE ONE  —  exactly 01:0, the jackpot\n\nRicher times pay more Points and more Mult.",
	},
	{
		"title": "Points × Mult",
		"body": "Your four locks build up Points and Mult.\n\nFinal score = Points × Mult.\n\nEach round has a target. Beat it and you move on; fall short and the run is over. Watch out — 6:66 is a Bad Time and scores nothing.",
	},
	{
		"title": "Jokers & the Shop",
		"body": "Clear a round and you get paid — then spend it in the Shop on Jokers.\n\nJokers add Mult, Points or money, and they resolve LEFT TO RIGHT, so a ×Mult card picks up every +Mult sitting to its left. Order is your build.\n\nGood luck.",
	},
]

@onready var _step: Label = $Panel/Box/Step
@onready var _title: Label = $Panel/Box/Title
@onready var _body: Label = $Panel/Box/Body
@onready var _back: Button = $Panel/Box/Row/Back
@onready var _next: Button = $Panel/Box/Row/Next

var _page: int = 0


func _ready() -> void:
	$Panel/Box/Row/Skip.pressed.connect(_start_game)
	_back.pressed.connect(_on_back)
	_next.pressed.connect(_on_next)
	_render()
	_next.grab_focus()
	Audio.play_music(&"menu")   # tutorial shares the calm menu theme


func _render() -> void:
	var p: Dictionary = PAGES[_page]
	Audio.play_sfx(&"speech")   # a little page-turn blip
	_step.text = "%d / %d" % [_page + 1, PAGES.size()]
	_title.text = String(p["title"])
	_body.text = String(p["body"])
	_back.disabled = _page == 0
	_next.text = "Start Run  ▶" if _page == PAGES.size() - 1 else "Next  ▶"


func _on_next() -> void:
	if _page >= PAGES.size() - 1:
		_start_game()
		return
	_page += 1
	_render()


func _on_back() -> void:
	if _page == 0:
		return
	_page -= 1
	_render()


func _start_game() -> void:
	get_tree().change_scene_to_file(GameScene)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		_on_next()
	elif event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
