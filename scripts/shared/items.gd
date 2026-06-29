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
const ID_SEED_BEETROOT: int = 1;
const ID_SEED_CABBAGE: int = 2;
const ID_SEED_CARROT: int = 3;
const ID_SEED_CAULIFLOWER: int = 4;
const ID_SEED_KALE: int = 5;
const ID_SEED_PARSNIP: int = 6;
const ID_SEED_POTATO: int = 7;
const ID_SEED_PUMPKIN: int = 8;
const ID_SEED_RADISH: int = 9;
const ID_SEED_SUNFLOWER: int = 10;
const ID_SEED_WHEAT: int = 11;

const ID_CROP_BEETROOT: int = 101;
const ID_CROP_CABBAGE: int = 102;
const ID_CROP_CARROT: int = 103;
const ID_CROP_CAULIFLOWER: int = 104;
const ID_CROP_KALE: int = 105;
const ID_CROP_PARSNIP: int = 106;
const ID_CROP_POTATO: int = 107;
const ID_CROP_PUMPKIN: int = 108;
const ID_CROP_RADISH: int = 109;
const ID_CROP_SUNFLOWER: int = 110;
const ID_CROP_WHEAT: int = 111;

const ID_FISH_SMALL:  int = 21;
const ID_FISH_MEDIUM: int = 22;
const ID_FISH_LARGE:  int = 23;

const ID_ROD_BAMBOO:  int = 31;
const ID_BAIT_NORMAL: int = 32;

const ID_POTION_HEALTH: int = 41;

static var CATALOGUE: Array[ItemData] = [];

const SERVER_ID_BY_INT_ID: Dictionary = {
	ID_SEED_BEETROOT: "seed_beetroot",
	ID_SEED_CABBAGE: "seed_cabbage",
	ID_SEED_CARROT: "seed_carrot",
	ID_SEED_CAULIFLOWER: "seed_cauliflower",
	ID_SEED_KALE: "seed_kale",
	ID_SEED_PARSNIP: "seed_parsnip",
	ID_SEED_POTATO: "seed_potato",
	ID_SEED_PUMPKIN: "seed_pumpkin",
	ID_SEED_RADISH: "seed_radish",
	ID_SEED_SUNFLOWER: "seed_sunflower",
	ID_SEED_WHEAT: "seed_wheat",
	ID_CROP_BEETROOT: "harvest_beetroot",
	ID_CROP_CABBAGE: "harvest_cabbage",
	ID_CROP_CARROT: "harvest_carrot",
	ID_CROP_CAULIFLOWER: "harvest_cauliflower",
	ID_CROP_KALE: "harvest_kale",
	ID_CROP_PARSNIP: "harvest_parsnip",
	ID_CROP_POTATO: "harvest_potato",
	ID_CROP_PUMPKIN: "harvest_pumpkin",
	ID_CROP_RADISH: "harvest_radish",
	ID_CROP_SUNFLOWER: "harvest_sunflower",
	ID_CROP_WHEAT: "harvest_wheat",
	ID_FISH_SMALL: "fish_small",
	ID_FISH_MEDIUM: "fish_medium",
	ID_FISH_LARGE: "fish_large",
	ID_ROD_BAMBOO: "rod_bamboo",
	ID_BAIT_NORMAL: "bait_normal",
};

const INT_ID_BY_SERVER_ID: Dictionary = {
	"seed_beetroot": ID_SEED_BEETROOT,
	"seed_cabbage": ID_SEED_CABBAGE,
	"seed_carrot": ID_SEED_CARROT,
	"seed_cauliflower": ID_SEED_CAULIFLOWER,
	"seed_kale": ID_SEED_KALE,
	"seed_parsnip": ID_SEED_PARSNIP,
	"seed_potato": ID_SEED_POTATO,
	"seed_pumpkin": ID_SEED_PUMPKIN,
	"seed_radish": ID_SEED_RADISH,
	"seed_sunflower": ID_SEED_SUNFLOWER,
	"seed_wheat": ID_SEED_WHEAT,
	"harvest_beetroot": ID_CROP_BEETROOT,
	"harvest_cabbage": ID_CROP_CABBAGE,
	"harvest_carrot": ID_CROP_CARROT,
	"harvest_cauliflower": ID_CROP_CAULIFLOWER,
	"harvest_kale": ID_CROP_KALE,
	"harvest_parsnip": ID_CROP_PARSNIP,
	"harvest_potato": ID_CROP_POTATO,
	"harvest_pumpkin": ID_CROP_PUMPKIN,
	"harvest_radish": ID_CROP_RADISH,
	"harvest_sunflower": ID_CROP_SUNFLOWER,
	"harvest_wheat": ID_CROP_WHEAT,
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
