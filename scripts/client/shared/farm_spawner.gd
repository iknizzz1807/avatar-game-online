extends Node2D
## Reads which cells are painted in [member farm_tilemap] and spawns a
## [FarmSlot] at the centre of each one at runtime.
##
## Tiles are sorted top-to-bottom, left-to-right before assigning plotId
## so the mapping is always deterministic regardless of paint order.

const FARM_SLOT_SCENE := preload("res://prefabs/farm_slot.tscn")

## Assign this to the TileMapLayer whose painted cells define the farm grid.
@export var farm_tilemap: TileMapLayer

func _ready() -> void:
	_spawn_slots()

func _spawn_slots() -> void:
	if not farm_tilemap:
		push_error("FarmSpawner: farm_tilemap is not assigned in the Inspector!")
		return

	# Collect every painted cell and sort top-to-bottom, left-to-right so that
	# plotId 0…N-1 is always in a stable, predictable order.
	var cells: Array[Vector2i] = farm_tilemap.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)

	for i in cells.size():
		var cell: Vector2i = cells[i]

		# map_to_local() returns the tile centre in the TileMapLayer's local space.
		# Convert to global then to this node's local space so that any parent
		# transform on either node is accounted for correctly.
		var world_pos: Vector2 = farm_tilemap.to_global(farm_tilemap.map_to_local(cell))
		var local_pos: Vector2  = to_local(world_pos)

		var slot: FarmSlot = FARM_SLOT_SCENE.instantiate()
		slot.plotId  = i
		slot.name    = "FarmSlot%d" % i
		slot.position = local_pos
		add_child(slot)
