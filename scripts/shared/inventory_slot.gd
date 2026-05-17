## Wraps one inventory slot for use in the Inspector.
## Add elements to Inventory.EXAMPLE_SLOTS and assign an ItemData + quantity.
extends Resource
class_name InventorySlot

@export var item: ItemData = null;
@export var quantity: int = 1;
