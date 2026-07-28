@tool
extends Node

@export var push_button_catalog: Dictionary[Enums.ButtonType, PushButtonDefinition]
@export var stopwatch_catalog: Dictionary[Enums.StopwatchType, StopwatchDefinition]

var _rng := RandomNumberGenerator.new()

func stopwatch_to_button(type: Enums.StopwatchType) -> Enums.ButtonType:
	match type:
		Enums.StopwatchType.NORMAL:
			return _rand_element([
				Enums.ButtonType.WHITE_CAT,
				Enums.ButtonType.NORMAL_WHITE,
				])
		Enums.StopwatchType.ROBOT:
			return _rand_element([
				Enums.ButtonType.BLACK_CAT,
				Enums.ButtonType.NORMAL_BLACK,
				])
		Enums.StopwatchType.CONSOLE:
			return Enums.ButtonType.PURPLE_CAT
		Enums.StopwatchType.CASSETTE:
			return Enums.ButtonType.BUBBLEGUM
	return Enums.ButtonType.NORMAL_WHITE


func _rand_element(array: Array):
	return array[_rng.randi_range(0, array.size() - 1)]
