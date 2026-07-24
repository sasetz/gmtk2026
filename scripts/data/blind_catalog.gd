class_name BlindCatalog
extends RefCounted

static var ANTES := [[
	BlindDef.new([
		[13_000, 0.5],
		[15_000, 0.5],
	], 300, 3),
	BlindDef.new([[11_000, 0.7]], 750, 4),
	BlindDef.new([[9_000, 0.7]], 1800, 5),
	BlindDef.new([[7_000, 0.7]], 3000, 7, 1, &"miser"),
]]

static func get_ante(id: int) -> Array:
	return ANTES[id]
