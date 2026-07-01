## The inventory stores { "resource": ItemData, "quantity": int } per slot.
extends Resource
class_name ItemData

@export_group("Identity")
@export var id: int = 0;
@export var itemName: String = "";
@export var icon: String = "❓"; # Fallback. Temp
@export var texture: Texture2D = null;

@export_group("Economy")
## 0 = not sold in shops.
@export var buyPrice: int = 0;
## 0 = cannot sell.
@export var sellPrice: int = 0;
@export var sellable: bool = false;

@export_group("Behaviour")
## Type string
@export var type: String = "";
@export var stackable: bool = true;

@export_group("Farming")
@export var growSecs: int = 0;
## ID of the ItemData produced when this seed is harvested (0 = none).
@export var yieldsId: int = 0;
## Index 0 = just seeded, last index = fully mature (READY).
@export var growthSprites: Array[Texture2D] = [];
