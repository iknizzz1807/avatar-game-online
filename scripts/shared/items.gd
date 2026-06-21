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

const SERVER_ID_BY_INT_ID: Dictionary = {
	ID_SEED_CARROT: "seed_carrot",
	ID_SEED_TOMATO: "seed_tomato",
	ID_SEED_CORN: "seed_corn",
	ID_CROP_CARROT: "harvest_carrot",
	ID_CROP_TOMATO: "harvest_tomato",
	ID_CROP_CORN: "harvest_corn",
	ID_FISH_SMALL: "fish_small",
	ID_FISH_MEDIUM: "fish_medium",
	ID_FISH_LARGE: "fish_large",
	ID_ROD_BAMBOO: "rod_bamboo",
	ID_BAIT_NORMAL: "bait_normal",
};

const INT_ID_BY_SERVER_ID: Dictionary = {
	"seed_carrot": ID_SEED_CARROT,
	"seed_tomato": ID_SEED_TOMATO,
	"seed_corn": ID_SEED_CORN,
	"harvest_carrot": ID_CROP_CARROT,
	"harvest_tomato": ID_CROP_TOMATO,
	"harvest_corn": ID_CROP_CORN,
	"fish_small": ID_FISH_SMALL,
	"fish_medium": ID_FISH_MEDIUM,
	"fish_large": ID_FISH_LARGE,
	"rod_bamboo": ID_ROD_BAMBOO,
	"bait_normal": ID_BAIT_NORMAL,
};

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


static func get_server_id(id: int) -> String:
	return SERVER_ID_BY_INT_ID.get(id, "")


static func get_item_by_server_id(server_id: String) -> ItemData:
	var int_id: int = int(INT_ID_BY_SERVER_ID.get(server_id, 0))
	return get_item(int_id) if int_id != 0 else null


static func build_item_from_server(data: Dictionary) -> ItemData:
	var item: ItemData = get_item_by_server_id(data.get("item_id", data.get("id", "")))
	if item != null:
		return item

	var fallback := ItemData.new()
	fallback.itemName = data.get("name", data.get("item_id", "Unknown"))
	fallback.type = data.get("type", "")
	fallback.sellPrice = int(data.get("sell_price", 0))
	fallback.buyPrice = int(data.get("buy_price", 0))
	fallback.sellable = fallback.sellPrice > 0
	fallback.stackable = true
	return fallback

## Returns every ItemData of a given [param type] (one of the TYPE_* constants).
static func get_by_type(type: String) -> Array[ItemData]:
	var result: Array[ItemData] = [];
	for item: ItemData in CATALOGUE:
		if item.type == type:
			result.append(item);
	return result;
