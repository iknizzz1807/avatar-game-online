extends Node
class_name Helper

static var rng : RandomNumberGenerator = RandomNumberGenerator.new();

static func choose(options : Array) -> Variant:
	return options.pick_random();

static func chance(percentage : float) -> bool:
	return rng.randf() < percentage;

static func map_value(value : float, iStart : float, iEnd : float, oStart : float, oEnd : float) -> float:
	return oStart + (clamp(value, iStart, iEnd) - iStart) / (iEnd - iStart) * (oEnd - oStart);
