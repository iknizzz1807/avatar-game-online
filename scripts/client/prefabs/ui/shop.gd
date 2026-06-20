extends Control
class_name ShopUI

@onready var item_container: VBoxContainer = $Panel/MarginContainer/VBox/ScrollContainer/VBoxContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/TitleBar/CloseButton

func _ready() -> void:
	close_button.pressed.connect(hide)
	add_to_group("shop_ui")
	hide()

func open_shop() -> void:
	_populate_shop()
	show()

func _populate_shop() -> void:
	for child in item_container.get_children():
		child.queue_free()

	for item: ItemData in Items.CATALOGUE:
		if item.buyPrice > 0:
			var row = HBoxContainer.new()
			
			if item.texture:
				var icon = TextureRect.new()
				icon.custom_minimum_size = Vector2(32, 32)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.texture = item.texture
				row.add_child(icon)
			else:
				var icon = Label.new()
				icon.custom_minimum_size = Vector2(32, 32)
				icon.text = item.icon
				icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				icon.add_theme_font_size_override("font_size", 24)
				row.add_child(icon)
			
			var name_label = Label.new()
			name_label.text = item.itemName
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(name_label)
			
			var price_label = Label.new()
			price_label.text = str(item.buyPrice) + " 🪙"
			price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(price_label)
			
			var buy_btn = Button.new()
			buy_btn.text = "Mua"
			var bind_item_id = item.id
			var bind_price = item.buyPrice
			buy_btn.pressed.connect(func(): _on_buy_requested(bind_item_id, bind_price))
			row.add_child(buy_btn)
			
			item_container.add_child(row)

func _on_buy_requested(item_id: int, price: int) -> void:
	var inventories = get_tree().get_nodes_in_group("inventory")
	if inventories.is_empty():
		push_error("Inventory not found!")
		return

	var inv = inventories[0]
	if inv.coins >= price:
		if inv.add_item(item_id, 1):
			inv.coins -= price
			inv.coins_changed.emit(inv.coins)
			if ToastManager:
				var bought_item = Items.get_item(item_id)
				var msg = "Đã mua " + bought_item.itemName if bought_item else "Đã mua vật phẩm"
				ToastManager.show_toast(msg)
		else:
			if ToastManager:
				ToastManager.show_toast("Túi đồ đã đầy!")
	else:
		if ToastManager:
			ToastManager.show_toast("Không đủ tiền!")
