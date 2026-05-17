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

# ─── Full catalogue ───────────────────────────────────────────────────────────
## Each dict:
##   id           int    — unique item ID (matches DB)
##   name         String — display name
##   icon         String — emoji fallback
##   texture_path String — res:// path to PNG sprite (empty = no sprite yet)
##   type         String — one of the TYPE_* constants
##   buy_price    int    — cost at shop (0 = not sold)
##   sell_price   int    — value when sold (0 = not sellable)
##   sellable     bool   — whether the player can sell from inventory
##   stackable    bool   — whether multiples share a slot (max 99)
##   grow_secs    int    — seconds to grow (seeds only, 0 otherwise)
##   yields_id    int    — item ID produced on harvest (seeds only, 0 otherwise)
const CATALOGUE: Array[Dictionary] = [
	# ── Seeds ──────────────────────────────────────────────────────────────
	{
		"id":           ID_SEED_CARROT,
		"name":         "Hạt Cà Rốt",
		"icon":         "🥕",
		"texture_path": "res://sprites/items/seed_carrot.png",
		"type":         TYPE_SEED,
		"buy_price":    50,
		"sell_price":   0,
		"sellable":     false,
		"stackable":    true,
		"grow_secs":    120,
		"yields_id":    ID_CROP_CARROT,
	},
	{
		"id":           ID_SEED_TOMATO,
		"name":         "Hạt Cà Chua",
		"icon":         "🍅",
		"texture_path": "res://sprites/items/seed_tomato.png",
		"type":         TYPE_SEED,
		"buy_price":    80,
		"sell_price":   0,
		"sellable":     false,
		"stackable":    true,
		"grow_secs":    300,
		"yields_id":    ID_CROP_TOMATO,
	},
	{
		"id":           ID_SEED_CORN,
		"name":         "Hạt Bắp",
		"icon":         "🌽",
		"texture_path": "res://sprites/items/seed_corn.png",
		"type":         TYPE_SEED,
		"buy_price":    120,
		"sell_price":   0,
		"sellable":     false,
		"stackable":    true,
		"grow_secs":    600,
		"yields_id":    ID_CROP_CORN,
	},
	# ── Crops ──────────────────────────────────────────────────────────────
	{
		"id":           ID_CROP_CARROT,
		"name":         "Cà Rốt",
		"icon":         "🥕",
		"texture_path": "res://sprites/items/crop_carrot.png",
		"type":         TYPE_CROP,
		"buy_price":    0,
		"sell_price":   90,
		"sellable":     true,
		"stackable":    true,
		"grow_secs":    0,
		"yields_id":    0,
	},
	{
		"id":           ID_CROP_TOMATO,
		"name":         "Cà Chua",
		"icon":         "🍅",
		"texture_path": "res://sprites/items/crop_tomato.png",
		"type":         TYPE_CROP,
		"buy_price":    0,
		"sell_price":   160,
		"sellable":     true,
		"stackable":    true,
		"grow_secs":    0,
		"yields_id":    0,
	},
	{
		"id":           ID_CROP_CORN,
		"name":         "Bắp",
		"icon":         "🌽",
		"texture_path": "res://sprites/items/crop_corn.png",
		"type":         TYPE_CROP,
		"buy_price":    0,
		"sell_price":   260,
		"sellable":     true,
		"stackable":    true,
		"grow_secs":    0,
		"yields_id":    0,
	},
	# ── Fish ───────────────────────────────────────────────────────────────
	{
		"id":           ID_FISH_SMALL,
		"name":         "Cá Nhỏ",
		"icon":         "🐟",
		"texture_path": "res://sprites/items/fish_small.png",
		"type":         TYPE_FISH,
		"buy_price":    0,
		"sell_price":   30,
		"sellable":     true,
		"stackable":    true,
		"grow_secs":    0,
		"yields_id":    0,
	},
	{
		"id":           ID_FISH_MEDIUM,
		"name":         "Cá Vừa",
		"icon":         "🐠",
		"texture_path": "res://sprites/items/fish_medium.png",
		"type":         TYPE_FISH,
		"buy_price":    0,
		"sell_price":   80,
		"sellable":     true,
		"stackable":    true,
		"grow_secs":    0,
		"yields_id":    0,
	},
	{
		"id":           ID_FISH_LARGE,
		"name":         "Cá Lớn",
		"icon":         "🐡",
		"texture_path": "res://sprites/items/fish_large.png",
		"type":         TYPE_FISH,
		"buy_price":    0,
		"sell_price":   200,
		"sellable":     true,
		"stackable":    true,
		"grow_secs":    0,
		"yields_id":    0,
	},
	# ── Tools & Bait ───────────────────────────────────────────────────────
	{
		"id":           ID_ROD_BAMBOO,
		"name":         "Cần Câu Tre",
		"icon":         "🎣",
		"texture_path": "res://sprites/items/rod_bamboo.png",
		"type":         TYPE_TOOL,
		"buy_price":    200,
		"sell_price":   0,
		"sellable":     false,
		"stackable":    false,
		"grow_secs":    0,
		"yields_id":    0,
	},
	{
		"id":           ID_BAIT_NORMAL,
		"name":         "Mồi Thường",
		"icon":         "🪱",
		"texture_path": "res://sprites/items/bait_normal.png",
		"type":         TYPE_BAIT,
		"buy_price":    20,
		"sell_price":   0,
		"sellable":     false,
		"stackable":    true,
		"grow_secs":    0,
		"yields_id":    0,
	},
];

# ─── Lookup helpers ───────────────────────────────────────────────────────────

## Returns the item dict for [param id], or an empty dict if not found.
static func get_item(id: int) -> Dictionary:
	for item: Dictionary in CATALOGUE:
		if item["id"] == id:
			return item;
	return {};

## Returns every item of a given [param type] (one of the TYPE_* constants).
static func get_by_type(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = [];
	for item: Dictionary in CATALOGUE:
		if item["type"] == type:
			result.append(item);
	return result;
