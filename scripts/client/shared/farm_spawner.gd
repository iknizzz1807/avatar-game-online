extends Node2D

## TilemapLayer -> FarmSlot spawner.

const FARM_SLOT_SCENE := preload("res://prefabs/farm_slot.tscn")

@export var farm_tilemap: TileMapLayer

func _ready() -> void:
	_spawn_slots()

func _spawn_slots() -> void:
	if not farm_tilemap:
		push_error("FarmSpawner: farm_tilemap is not assigned in the Inspector!")
		return

	var cells: Array[Vector2i] = farm_tilemap.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)

	for i in cells.size():
		var cell: Vector2i = cells[i]

		var world_pos: Vector2 = farm_tilemap.to_global(farm_tilemap.map_to_local(cell))
		var local_pos: Vector2  = to_local(world_pos)

		var slot: FarmSlot = FARM_SLOT_SCENE.instantiate()
		slot.plotId  = i
		slot.name    = "FarmSlot%d" % i
		slot.position = local_pos
		add_child(slot)
