extends Node

enum ButtonType {
	NORMAL_WHITE,
	NORMAL_BLACK,
	WHITE_CAT,
	BLACK_CAT,
	PURPLE_CAT,
	BUBBLEGUM,
}

enum StopwatchType {
	NORMAL,
	ROBOT,
	CONSOLE,
	CASSETTE,
}

func random_stopwatch(rng: RandomNumberGenerator) -> StopwatchType:
	return StopwatchType.values()[rng.randi_range(0, StopwatchType.size() - 1)]
