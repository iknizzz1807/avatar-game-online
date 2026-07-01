extends ContextMenuTarget
class_name ShopkeeperInteraction

func _build_actions() -> Array:
	return [
		{ "id": "shop", "label": tr("SHOP_ACTION") }
	];

func _on_context_action(actionId: String, target: Object) -> void:
	if target != self: return
	match actionId:
		"shop":
			var shops = get_tree().get_nodes_in_group("shop_ui");
			if shops.size() > 0:
				shops[0].open_shop();
			else:
				push_warning("Shop UI not found! Make sure shop.tscn is added to CanvasLayer and is in 'shop_ui' group.");
