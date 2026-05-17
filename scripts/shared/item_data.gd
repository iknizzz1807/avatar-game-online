## Typed resource representing a single item definition.
## Create .tres instances in resources/items/ for each item in the game.
## The inventory stores { "resource": ItemData, "quantity": int } per slot.
extends Resource
class_name ItemData

@export_group("Identity")
@export var id: int = 0;
@export var itemName: String = "";
## Emoji shown as fallback when no texture is assigned.
@export var icon: String = "❓";
@export var texture: Texture2D = null;

@export_group("Economy")
## Purchase price at any shop (0 = not sold in shops).
@export var buyPrice: int = 0;
## Value when the player sells this item (0 = cannot sell).
@export var sellPrice: int = 0;
@export var sellable: bool = false;

@export_group("Behaviour")
## Type string — matches Items.TYPE_* constants.
@export var type: String = "";
## Whether multiple units stack in one inventory slot (max 99).
@export var stackable: bool = true;

@export_group("Farming")
## Seconds from watering to harvest (0 for non-seed items).
@export var growSecs: int = 0;
## ID of the ItemData produced when this seed is harvested (0 = none).
@export var yieldsId: int = 0;
