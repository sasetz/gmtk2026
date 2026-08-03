extends Node
## Central audio: looping background music with crossfades, and a pooled,
## variant-randomised SFX layer. Everything routes through the Music / SFX buses
## (see default_bus_layout.tres) so the options sliders already control it.
##
## Design goals:
##  - Scenes stay audio-agnostic where possible: money/buy/sell sounds ride
##    EventBus, and EVERY button plays a click via a global node_added hook, so
##    the menus needed no per-button wiring.
##  - Variant sounds (chip/coin/card…) pick a random file AND a slight random
##    pitch each time, so repeated actions never sound like a machine gun.
##  - Runs with PROCESS_MODE_ALWAYS so pause-menu clicks and music keep working
##    while get_tree().paused is true.

## From which lap the music switches to the intense track.
const INTENSE_FROM_LAP: int = 3

# Two music players so a change crossfades instead of hard-cutting.
var _current_track: StringName = &""

var _last_money: int = -1
var _rng := RandomNumberGenerator.new()

var MusicPlayer: AudioStreamPlayer

var _button_players: Dictionary[Enums.ButtonType, AudioStreamPlayer]
var _stopwatch_players: Dictionary[Enums.StopwatchType, AudioStreamPlayer]
var _sfx_players: Dictionary[StringName, AudioStreamPlayer]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_button_players()
	_build_stopwatch_players()
	_build_sfx_players()
	_connect_events()

# --- music --------------------------------------------------------------------

## Crossfade to a named track (menu / round / shop). A no-op if it's already
## the current one, so scenes can call it freely on every _ready.
func play_music(track: StringName) -> void:
	if not MusicPlayer:
		return
	if track == _current_track:
		return
	_current_track = track
	if not MusicPlayer.playing:
		MusicPlayer.play()
	MusicPlayer.get_stream_playback().switch_to_clip_by_name(track)


func stop_music() -> void:
	if not MusicPlayer:
		return
	_current_track = &""
	MusicPlayer.stop()


## Which track a round should play: it turns intense once the run is deep enough.
## Kept separate from playing it so the rule can be reasoned about on its own.
func round_track() -> StringName:
	return &"Intense" if RunManager.lap >= INTENSE_FROM_LAP else &"Normal"


func play_round_music() -> void:
	play_music(round_track())

# --- gameplay event cues ------------------------------------------------------

func _connect_events() -> void:
	# _last_money starts at -1 so the first money_changed (the run's opening
	# balance) just sets the baseline instead of jingling.
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.card_bought.connect(func(_j) -> void: sfx(&"card_slide"))
	EventBus.card_sold.connect(func(_j) -> void: sfx(&"crumple"))
	EventBus.round_started.connect(func() -> void: sfx(&"chips"))
	EventBus.shop_entered.connect(func() -> void: sfx(&"coin"))
	EventBus.round_result.connect(_on_round_result)


## Round over: a payoff sting when it went well, a flat cancel when it did not.
func _on_round_result(won: bool, is_boss: bool, _reward: int) -> void:
	if won:
		sfx(&"multipoints" if is_boss else &"points")
	else:
		sfx(&"ui_cancel")
		play_music(&"Loser")


## Coin jingle only when money goes UP — resets and purchases (which lower it)
## stay quiet, so the coin means "you got paid".
func _on_money_changed(amount: int) -> void:
	if _last_money >= 0 and amount > _last_money:
		sfx(&"coin")
	_last_money = amount


## play selected sound effect, if it is defined
func sfx(sfx_name: StringName) -> void:
	var player: AudioStreamPlayer = _sfx_players.get(sfx_name)
	if not player:
		push_error("[Audio] Couldn't find the '%s' sound effect in the ResourceCatalog!" % sfx_name)
		return
	player.play()


func _build_sfx_players() -> void:
	for sfx_name in ResourceCatalog.sfx.keys():
		var player = AudioStreamPlayer.new()
		player.stream = ResourceCatalog.sfx[sfx_name]
		player.autoplay = false
		add_child(player)
		_sfx_players.set(sfx_name, player)


func _build_stopwatch_players() -> void:
	for stopwatch_type in Enums.StopwatchType.values():
		if not ResourceCatalog.stopwatch_catalog.has(stopwatch_type):
			continue
		var player = AudioStreamPlayer.new()
		player.stream = ResourceCatalog.stopwatch_catalog[stopwatch_type].tick
		player.autoplay = false
		add_child(player)
		_stopwatch_players.set(stopwatch_type, player)


func stopwatch_tick(type: Enums.StopwatchType) -> void:
	_stopwatch_players[type].play()


func _build_button_players() -> void:
	for button_type in Enums.ButtonType.values():
		if not ResourceCatalog.push_button_catalog.has(button_type):
			continue
		var player = AudioStreamPlayer.new()
		player.stream = ResourceCatalog.push_button_catalog[button_type].sounds
		player.autoplay = false
		add_child(player)
		_button_players.set(button_type, player)


# done through here to ensure button sound survives button free
func button(type: Enums.ButtonType) -> void:
	_button_players[type].play()
