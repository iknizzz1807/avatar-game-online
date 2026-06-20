## Shared item database — single source of truth for ALL items in the game.
## Both client UI and server-side logic reference these IDs and values.
## Do NOT change IDs after release; they are stored in the DB.
class_name Items

# ─── Item types ───────────────────────────────────────────────────────────────
const TYPE_SEED: String = "seed";
const TYPE_CROP: String = "crop";
const TYPE_FISH: String = "fish";
const TYPE_TOOL: String = "tool";
const TYPE_BAIT: String = "bait";
const TYPE_POTION: String = "potion";

# ─── Item IDs ─────────────────────────────────────────────────────────────────
const ID_SEED_CARROT: int = 1;
const ID_SEED_TOMATO: int = 2;
const ID_SEED_CORN:   int = 3;

const ID_CROP_CARROT: int = 11;
const ID_CROP_TOMATO: int = 12;
const ID_CROP_CORN:   int = 13;

const ID_FISH_SMALL:  int = 21;
const ID_FISH_MEDIUM: int = 22;
const ID_FISH_LARGE:  int = 23;

const ID_ROD_BAMBOO:  int = 31;
const ID_BAIT_NORMAL: int = 32;

const ID_POTION_HEALTH: int = 41;

static var CATALOGUE: Array[ItemData] = [];

static func _static_init() -> void:
	var path: String = "res://resources/items/"
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(path + file_name) as ItemData
				if res:
					CATALOGUE.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()

# ─── Lookup helpers ───────────────────────────────────────────────────────────

## Returns the ItemData resource for [param id], or null if not found.
static func get_item(id: int) -> ItemData:
	for item: ItemData in CATALOGUE:
		if item.id == id:
			return item;
	return null;

## Returns every ItemData of a given [param type] (one of the TYPE_* constants).
static func get_by_type(type: String) -> Array[ItemData]:
	var result: Array[ItemData] = [];
	for item: ItemData in CATALOGUE:
		if item.type == type:
			result.append(item);
	return result;
