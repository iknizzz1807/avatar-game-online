extends Control
class_name Inventory

# ═════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═════════════════════════════════════════════════════════════════════════════

signal sell_requested(itemId: String, quantity: int);
signal close_requested();
signal coins_changed(amount: int);
## Fired whenever inventoryData changes so the Hotbar (and other listeners) can refresh.
signal inventory_updated(data: Array);

# ═════════════════════════════════════════════════════════════════════════════
# INSPECTOR — Example data (editable in the Godot editor)
# Assign ItemData resources and quantities directly in the Inspector.
# These are loaded on _ready() and used until the Go Server sends real data.
# ═════════════════════════════════════════════════════════════════════════════

@export_group("Example Data")
@export var EXAMPLE_SLOTS: Array[InventorySlot] = [];

# ═════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═════════════════════════════════════════════════════════════════════════════

const SLOT_COUNT: int = 20;

# ═════════════════════════════════════════════════════════════════════════════
# NODES
# ═════════════════════════════════════════════════════════════════════════════

@onready var gridContainer: GridContainer = $TabContainer/InventoryPanel/MC/VBox/GridContainer;
@onready var closeButton: Button = $TabContainer/InventoryPanel/MC/VBox/TitleBar/CloseButton;
@onready var closeButton2: Button = $TabContainer/FriendsPanel/MC/VBox/TitleBar/CloseButton2;
@onready var logoutButton1: Button = $TabContainer/InventoryPanel/MC/VBox/TitleBar/LogoutButton;
@onready var logoutButton2: Button = $TabContainer/FriendsPanel/MC/VBox/TitleBar/LogoutButton2;
@onready var tooltipSection: VBoxContainer = $TabContainer/InventoryPanel/MC/VBox/TooltipSection;
@onready var tooltipName: Label = $TabContainer/InventoryPanel/MC/VBox/TooltipSection/TooltipName;
@onready var tooltipSellButton: Button = $TabContainer/InventoryPanel/MC/VBox/TooltipSection/SellButton;

@onready var tabContainer: TabContainer = $TabContainer;
@onready var friendsList: ItemList = $TabContainer/FriendsPanel/MC/VBox/FriendsTab/FriendsColumn/FriendsList;
@onready var removeFriendButton: Button = $TabContainer/FriendsPanel/MC/VBox/FriendsTab/FriendsColumn/RemoveFriendButton;
@onready var requestsList: ItemList = $TabContainer/FriendsPanel/MC/VBox/FriendsTab/RequestsColumn/RequestsList;
@onready var acceptButton: Button = $TabContainer/FriendsPanel/MC/VBox/FriendsTab/RequestsColumn/RequestButtons/AcceptButton;
@onready var declineButton: Button = $TabContainer/FriendsPanel/MC/VBox/FriendsTab/RequestsColumn/RequestButtons/DeclineButton;

# ═════════════════════════════════════════════════════════════════════════════
# STATE
# ═════════════════════════════════════════════════════════════════════════════

## 20-element array. Each element is one of:
##   { "resource": ItemData, "quantity": int }  — filled slot
##   {}                                          — empty slot
var inventoryData: Array = [];
var slots: Array[ItemSlot] = [];
var selectedSlot: int = -1;
var _friends_data: Array = [];
var _selected_context_friend: Dictionary = {};

# TODO(Backend): Sync coins from the Go server instead of local simulation
var coins: int = 1000;

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("inventory");
	closeButton.pressed.connect(_on_close_pressed);
	closeButton2.pressed.connect(_on_close_pressed);
	tooltipSellButton.pressed.connect(_on_sell_pressed);
	
	logoutButton1.pressed.connect(_on_logout_pressed)
	logoutButton2.pressed.connect(_on_logout_pressed)

	removeFriendButton.pressed.connect(_on_remove_friend_pressed)
	acceptButton.pressed.connect(_on_accept_pressed)
	declineButton.pressed.connect(_on_decline_pressed)
	FriendManager.friends_updated.connect(_on_friends_updated)
	friendsList.item_clicked.connect(_on_friend_item_clicked)
	
	tabContainer.set_tab_title(0, tr("INVENTORY_TAB"))
	tabContainer.set_tab_title(1, tr("FRIENDS_TAB"))
	
	$TabContainer/FriendsPanel/MC/VBox/FriendsTab/FriendsColumn/FriendsTitle.text = tr("FRIENDS")
	removeFriendButton.text = tr("REMOVE_FRIEND")
	$TabContainer/FriendsPanel/MC/VBox/FriendsTab/RequestsColumn/RequestsTitle.text = tr("FRIEND_REQUESTS")
	acceptButton.text = tr("ACCEPT")
	declineButton.text = tr("DECLINE")
	
	_collect_slots();
	# Connect hotbar nodes so they refresh whenever the inventory changes.
	inventory_updated.connect(_on_inventory_updated_hotbar);
	if ApiClient.has_auth_token():
		load_inventory()
		FriendManager.load_friends()
		_refresh_friend_requests()
	else:
		_load_example_slots();

# ═════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═════════════════════════════════════════════════════════════════════════════

## Load fresh inventory from Go Server.
## [param data] Array of { "resource": ItemData, "quantity": int } or {}.
## Automatically padded / trimmed to exactly SLOT_COUNT.
func set_inventory(data: Array) -> void:
	inventoryData = data.duplicate();
	while inventoryData.size() < SLOT_COUNT:
		inventoryData.append({});
	inventoryData.resize(SLOT_COUNT);
	_refresh_slots();

func open_inventory() -> void:
	if ApiClient.has_auth_token():
		load_inventory()
		FriendManager.load_friends()
		_refresh_friend_requests()
	visible = true;


func load_inventory() -> void:
	var response: Dictionary = await ApiClient.request_json("/api/inventory")
	if not response.get("ok", false):
		ToastManager.show_toast(tr("FAILED_TO_LOAD_INVENTORY"), ToastManager.Type.WARNING)
		return
	var data: Dictionary = ApiClient.response_data(response)
	set_server_inventory(data.get("inventory", []))


func set_server_inventory(items: Array) -> void:
	var data: Array = []
	for server_item in items:
		if not server_item is Dictionary:
			continue
		var item_data: Dictionary = server_item
		data.append({
			"resource": Items.build_item_from_server(item_data),
			"quantity": int(item_data.get("quantity", 1)),
			"server_id": item_data.get("item_id", ""),
		})
	set_inventory(data)

## Attempts to add an item to the inventory. Returns true if successful.
func add_item(item_id: int, quantity: int) -> bool:
	var item_res = Items.get_item(item_id);
	if not item_res:
		return false;

	# Try to find an existing stack if stackable
	if item_res.stackable:
		for i in range(inventoryData.size()):
			if not inventoryData[i].is_empty() and inventoryData[i]["resource"].id == item_id:
				# TODO(Backend): Sync item addition with Go server
				inventoryData[i]["quantity"] += quantity;
				_refresh_slots();
				return true;
				
	# Find an empty slot
	for i in range(inventoryData.size()):
		if inventoryData[i].is_empty():
			# TODO(Backend): Sync item addition with Go server
			inventoryData[i] = { "resource": item_res, "quantity": quantity };
			_refresh_slots();
			return true;
			
	return false;

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE — build & refresh
# ═════════════════════════════════════════════════════════════════════════════

## Gather the 20 ItemSlot instances already placed in the scene by the editor.
func _collect_slots() -> void:
	for child: Node in gridContainer.get_children():
		var slot: ItemSlot = child as ItemSlot;
		if slot == null:
			continue;
		slot.slotIndex = slots.size();
		slot.slot_clicked.connect(_on_slot_clicked);
		slot.swap_requested.connect(_on_slot_swap);
		slots.append(slot);

## Convert EXAMPLE_SLOTS export array into inventoryData and display it.
func _load_example_slots() -> void:
	var data: Array = [];
	for s: InventorySlot in EXAMPLE_SLOTS:
		if s != null and s.item != null:
			data.append({"resource": s.item, "quantity": s.quantity});
		else:
			data.append({});
	set_inventory(data);

func _refresh_slots() -> void:
	for i: int in range(slots.size()):
		slots[i].set_item(inventoryData[i] if i < inventoryData.size() else {});
	_hide_tooltip();
	inventory_updated.emit(inventoryData);

# ═════════════════════════════════════════════════════════════════════════════
# PRIVATE — event handlers
# ═════════════════════════════════════════════════════════════════════════════

func _on_slot_clicked(idx: int) -> void:
	if selectedSlot >= 0:
		slots[selectedSlot].set_selected(false);

	if selectedSlot == idx or inventoryData[idx].is_empty():
		selectedSlot = -1;
		_hide_tooltip();
		return ;

	selectedSlot = idx;
	slots[selectedSlot].set_selected(true);

	var res: ItemData = inventoryData[idx]["resource"] as ItemData;
	tooltipName.text = tr(res.itemName);
	tooltipSellButton.visible = res.sellable or inventoryData[idx].get("server_id", "").begins_with("harvest_") or inventoryData[idx].get("server_id", "").begins_with("fish_");
	tooltipSection.visible = true;

func _on_slot_swap(fromIndex: int, toIndex: int) -> void:
	if fromIndex == toIndex:
		return ;
	var fromData: Dictionary = inventoryData[fromIndex];
	var toData: Dictionary = inventoryData[toIndex];
	inventoryData[fromIndex] = toData;
	inventoryData[toIndex] = fromData;
	slots[fromIndex].set_item(toData);
	slots[toIndex].set_item(fromData);
	_hide_tooltip();

func _on_sell_pressed() -> void:
	if selectedSlot < 0:
		return ;
	var res: ItemData = inventoryData[selectedSlot]["resource"] as ItemData;
	var qty: int = inventoryData[selectedSlot].get("quantity", 0);
	var server_id: String = inventoryData[selectedSlot].get("server_id", Items.get_server_id(res.id));
	if ApiClient.has_auth_token() and not server_id.is_empty():
		var response: Dictionary = await ApiClient.request_json(
			"/api/inventory/sell",
			HTTPClient.METHOD_POST,
			{ "item_id": server_id, "quantity": qty }
		)
		if response.get("ok", false):
			ToastManager.show_toast(tr("ITEM_SOLD"))
			load_inventory()
		else:
			ToastManager.show_toast(tr("FAILED_TO_SELL_ITEM"), ToastManager.Type.WARNING)
	else:
		sell_requested.emit(server_id, qty);
	_hide_tooltip();

func _on_close_pressed() -> void:
	_hide_tooltip();
	close_requested.emit();
	hide();

func _hide_tooltip() -> void:
	if selectedSlot >= 0:
		slots[selectedSlot].set_selected(false);
	tooltipSection.visible = false;
	selectedSlot = -1;

func _on_inventory_updated_hotbar(data: Array) -> void:
	for hotbar in get_tree().get_nodes_in_group("hotbar"):
		if hotbar.has_method("populate"):
			hotbar.populate(data)


func _on_friends_updated(friends: Array) -> void:
	_friends_data = friends
	friendsList.clear()
	for friend in friends:
		if friend is Dictionary:
			var name: String = str(friend.get("display_name", ""))
			var map: String = str(friend.get("current_map", ""))
			var label: String = "%s (%s)" % [name, map] if not map.is_empty() else name
			var idx: int = friendsList.add_item(label)
			friendsList.set_item_metadata(idx, friend.get("id", -1))


func _on_friend_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	if index < 0 or index >= _friends_data.size():
		return
	var friend = _friends_data[index]
	_show_friend_context_menu(friend, get_global_mouse_position())


func _show_friend_context_menu(friend: Dictionary, screen_pos: Vector2) -> void:
	var menus := get_tree().get_nodes_in_group("context_menu")
	if menus.is_empty():
		return
	var menu = menus[0]
	if menu.action_selected.is_connected(_on_friend_context_action):
		menu.action_selected.disconnect(_on_friend_context_action)
	menu.action_selected.connect(_on_friend_context_action, CONNECT_ONE_SHOT)
	
	_selected_context_friend = friend
	
	var in_farm: bool = (MultiplayerManager.local_scene_name == "game")
	var actions = [
		{
			"id": "invite_to_farm",
			"label": tr("INVITE_TO_FARM"),
			"enabled": in_farm,
			"tooltip": "" if in_farm else tr("MUST_BE_IN_FARM_TO_INVITE")
		}
	]
	
	menu.show_menu(actions, self, screen_pos)


func _on_friend_context_action(actionId: String, target: Object) -> void:
	if target != self:
		return
	match actionId:
		"invite_to_farm":
			if _selected_context_friend.is_empty():
				return
			var friend_id = _selected_context_friend.get("id", -1)
			if friend_id > 0:
				MultiplayerManager.send_farm_invite(friend_id)


func _refresh_friend_requests() -> void:
	requestsList.clear()
	if not ApiClient.has_auth_token():
		return
	var response: Dictionary = await ApiClient.request_json("/api/friends/requests")
	if not response.get("ok", false):
		return
	var requests: Array = ApiClient.response_data(response).get("requests", [])
	for request in requests:
		if request is Dictionary:
			var name: String = str(request.get("requester_name", ""))
			var label: String = name
			var idx: int = requestsList.add_item(label)
			requestsList.set_item_metadata(idx, request.get("id", -1))


func _on_remove_friend_pressed() -> void:
	var selected: PackedInt32Array = friendsList.get_selected_items()
	if selected.is_empty():
		return
	var friend_id = friendsList.get_item_metadata(selected[0])
	if friend_id is int and friend_id > 0:
		await FriendManager.remove_friend(friend_id)


func _on_accept_pressed() -> void:
	var selected: PackedInt32Array = requestsList.get_selected_items()
	if selected.is_empty():
		return
	var request_id = requestsList.get_item_metadata(selected[0])
	if request_id is int and request_id > 0:
		await FriendManager.accept_request(request_id)
		_refresh_friend_requests()


func _on_decline_pressed() -> void:
	var selected: PackedInt32Array = requestsList.get_selected_items()
	if selected.is_empty():
		return
	var request_id = requestsList.get_item_metadata(selected[0])
	if request_id is int and request_id > 0:
		await FriendManager.decline_request(request_id)
		_refresh_friend_requests()


func _on_logout_pressed() -> void:
	var confirm_dialog := ConfirmationDialog.new()
	confirm_dialog.title = tr("CONFIRM_LOGOUT")
	confirm_dialog.dialog_text = tr("CONFIRM_LOGOUT_PROMPT")
	confirm_dialog.confirmed.connect(func() -> void:
		confirm_dialog.queue_free()
		hide()
		MultiplayerManager.disconnect_from_server()
		ApiClient.clear_auth_token()
		MultiplayerManager.set_auth_token("")
		TransitionManager.transition_to("res://scenes/auth.tscn")
	)
	confirm_dialog.canceled.connect(func() -> void:
		confirm_dialog.queue_free()
	)
	get_tree().root.add_child(confirm_dialog)
	confirm_dialog.popup_centered()
