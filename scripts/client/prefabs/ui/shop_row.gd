extends Control
class_name ShopRow

signal buy_requested(item_id: String, price: int)

@onready var icon_texture: TextureRect = $CenterContainer/ShopRow/IconTexture
@onready var icon_label: Label = $CenterContainer/ShopRow/IconLabel
@onready var name_label: Label = $CenterContainer/ShopRow/NameLabel
@onready var price_label: Label = $CenterContainer/ShopRow/PriceLabel
@onready var buy_button: Button = $CenterContainer/ShopRow/BuyButton

var _item_id: String
var _price: int

func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)

func setup(item_id: String, item: ItemData, price: int) -> void:
	_item_id = item_id
	_price = price
	
	if item.texture:
		icon_texture.texture = item.texture
		icon_texture.show()
		icon_label.hide()
	else:
		icon_label.text = item.icon
		icon_label.show()
		icon_texture.hide()
		
	name_label.text = item.itemName
	price_label.text = str(price) + " Xu"

func _on_buy_pressed() -> void:
	buy_requested.emit(_item_id, _price)
