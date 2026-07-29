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

const DIR: String = "res://assets/sounds/"

## Logical name → interchangeable variant files. play_sfx() picks one at random.
const SFX := {
	&"ui_click": ["button press 1.wav", "Button Press 2.wav", "click.wav"],
	&"ui_cancel": ["cancel.wav"],
	&"card": ["card flick.wav", "card flick 2.wav", "card flick 3.wav"],
	&"card_slide": ["card slide.wav"],
	&"chip": ["chip.wav", "chip 2.wav", "chip 3.wav"],
	&"coin": ["coin.wav", "coin 2.wav", "coin 3.wav"],
	&"point": ["point.wav"],
	&"multihit": ["multihit multipoints.wav"],
	&"clock": ["clock tick 1.wav", "Clock tick 2.wav"],
	&"crumple": ["crumple.wav", "crumple 2.wav", "crumple 3.wav"],
	&"jimbo": ["Jimbo Speak 01.wav", "Jimbo Speak 02.wav", "Jimbo Speak 03.wav",
		"Jimbo Speak 04.wav", "Jimbo Speak 05.wav"],
	&"speech": ["speech bubble 1.wav", "speech bubble 2.wav", "speech bubble 3.wav",
		"speech bubble 4.wav"],

	# One press sound per button LOOK, so a keycap, a gumball machine and the cat
	# each sound like themselves.
	&"btn_normal": ["button press 1.wav", "Button Press 2.wav"],
	&"btn_keyboard": ["Keyboard Button Press 1.wav", "Keyboard Button Press 2.wav",
		"Keyboard Button Press 3.wav"],
	&"btn_gumball": ["Gumball Button Press.wav", "Gumball Button Press 2.wav",
		"Gumball Button Press 3.wav"],
	&"btn_cat": ["Jaimie Cat Button Press.wav", "Jaimie Cat Button Press 2.wav",
		"Jaimie Cat Button Press 3.wav"],

	# And one tick per stopwatch face.
	&"tick_normal": ["clock tick 1.wav", "Clock tick 2.wav"],
	&"tick_cassette": ["Cassette Click 1.wav", "Cassette Click 2.wav"],
	&"tick_robot": ["Robot Tick.wav", "Robot Tick 2.wav"],
	&"tick_console": ["Console Tick 1.wav", "Console Tick 2.wav"],
}

## Stopwatch face → its tick. The art drives the choice: the purple one is a
## handheld console, the pink one a cassette deck, the digital one a robot.
const FACE_TICKS := {
	&"default": &"tick_normal",
	&"grey": &"tick_normal",
	&"purple": &"tick_console",
	&"pink": &"tick_cassette",
	&"digital": &"tick_robot",
}

## Button sheet → the press it makes, matched to the artist's own naming so the
## sound cannot drift away from the art: a cat button meows, a bumblegum machine
## rattles, a plain keycap clacks.
const SHEET_SOUNDS := {
	&"button_white_cat": &"btn_cat",
	&"button_black_cat": &"btn_cat",
	&"button_bumblegum": &"btn_gumball",
	&"button_white_normal": &"btn_normal",
	&"button_black_normal": &"btn_normal",
}

## Consumable button id → its press sound, picked to match its keycap art.
const BUTTON_SOUNDS := {
	&"consecutive": &"btn_keyboard",
	&"remaining_seconds": &"btn_keyboard",
	&"gap": &"btn_keyboard",
	&"high_decimal": &"btn_gumball",
	&"remaining_clicks": &"btn_normal",
}

## From which lap the music switches to the intense track.
const INTENSE_FROM_LAP: int = 3

const SFX_VOICES: int = 10
const MUSIC_DB: float = -6.0          # headroom so music sits under the SFX
const FADE_TIME: float = 0.6
const SILENT_DB: float = -60.0

var _sfx_streams: Dictionary = {}     # name → Array[AudioStream]
var _last_variant: Dictionary = {}    # name → last variant index played
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

## Random pitch spread applied to every cue (±), so repeats never sound identical.
const PITCH_SPREAD: float = 0.11

# Two music players so a change crossfades instead of hard-cutting.
var _current_track: StringName = &""

var _last_money: int = -1
var _rng := RandomNumberGenerator.new()

var MusicPlayer: AudioStreamPlayer

var _button_players: Dictionary[Enums.ButtonType, AudioStreamPlayer]
var _stopwatch_players: Dictionary[Enums.StopwatchType, AudioStreamPlayer]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_button_players()
	_build_stopwatch_players()
	_load_sfx()
	_build_voices()
	_connect_events()


# --- SFX --------------------------------------------------------------------

func _load_sfx() -> void:
	for name: StringName in SFX:
		var streams: Array = []
		for file: String in SFX[name]:
			var s: AudioStream = load(DIR + file)
			if s != null:
				streams.append(s)
			else:
				push_warning("Audio: missing SFX file %s" % file)
		_sfx_streams[name] = streams


func _build_voices() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voices.append(p)


## Play a sound by logical name. `pitch` is the centre pitch; a small random
## spread is added so repeats feel alive. `volume_db` trims individual cues.
func play_sfx(name: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var streams: Array = _sfx_streams.get(name, [])
	if streams.is_empty():
		return
	var idx: int = _pick_variant(name, streams.size())
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = streams[idx]
	voice.pitch_scale = clampf(pitch + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD), 0.1, 4.0)
	voice.volume_db = volume_db
	voice.play()


## Choose a variant index, never the same one twice in a row for a given sound —
## consecutive repeats are exactly what makes randomisation sound like no
## randomisation. With one variant there's nothing to vary, so return it.
func _pick_variant(name: StringName, count: int) -> int:
	if count <= 1:
		return 0
	var last: int = int(_last_variant.get(name, -1))
	var idx: int = _rng.randi_range(0, count - 2)
	if idx >= last:
		idx += 1   # skip the last-played index, so every other stays equally likely
	_last_variant[name] = idx
	return idx


# --- music ------------------------------------------------------------------

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

# --- gameplay event cues ----------------------------------------------------

func _connect_events() -> void:
	# _last_money starts at -1 so the first money_changed (the run's opening
	# balance) just sets the baseline instead of jingling.
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.card_bought.connect(func(_j) -> void: play_sfx(&"card_slide"))
	EventBus.card_sold.connect(func(_j) -> void: play_sfx(&"crumple"))
	EventBus.round_started.connect(func() -> void: play_sfx(&"chip"))
	EventBus.shop_entered.connect(func() -> void: play_sfx(&"coin"))
	EventBus.round_result.connect(_on_round_result)


## Round over: a payoff sting when it went well, a flat cancel when it did not.
func _on_round_result(won: bool, is_boss: bool, _reward: int) -> void:
	if won:
		play_sfx(&"multihit" if is_boss else &"point")
	else:
		play_sfx(&"ui_cancel")
		play_music(&"Loser")


## Coin jingle only when money goes UP — resets and purchases (which lower it)
## stay quiet, so the coin means "you got paid".
func _on_money_changed(amount: int) -> void:
	if _last_money >= 0 and amount > _last_money:
		play_sfx(&"coin")
	_last_money = amount


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
