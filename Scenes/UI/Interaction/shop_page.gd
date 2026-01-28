extends Node
class_name InteractionShopController

@export var shop_rows_parent: VBoxContainer
@export var buy_button: Button
@export var row_scene: PackedScene

# Buying uses ResourceManager (scrap)
@export var currency_id: String = "scrap"

# Optional: if you have an inventory node, drag it in
@export var player_inventory: Node

var _planet: Node = null
var _offers: Array[ShopOffer] = []
var _rows: Array[ShopItemRow] = []
var _selected_index: int = -1

var _resource_manager: Node = null


func _ready() -> void:
	if buy_button != null:
		buy_button.pressed.connect(_on_buy_pressed)

	_resource_manager = get_node_or_null("/root/ResourceManager")
	if _resource_manager != null and _resource_manager.has_signal("resource_changed"):
		if not _resource_manager.resource_changed.is_connected(_on_resource_changed):
			_resource_manager.resource_changed.connect(_on_resource_changed)


func setup_for_planet(planet: Node) -> void:
	_planet = planet
	refresh()


func stop() -> void:
	_planet = null
	_clear_rows()


func refresh() -> void:
	_clear_rows()

	if shop_rows_parent == null:
		return
	if _planet == null or not is_instance_valid(_planet):
		return

	_offers = _extract_shop_offers_from_planet(_planet)
	_build_rows(_offers)

	_set_selected_index(-1)
	_update_buy_button_state()


func _on_resource_changed(resource_id: String, new_amount: int) -> void:
	if resource_id != currency_id:
		return
	_update_buy_button_state()


# -------------------------------------------------------------------
# Extraction (dialogue-style safe lookup)
# -------------------------------------------------------------------

func _extract_shop_offers_from_planet(planet: Node) -> Array[ShopOffer]:
	# 1) planet.shop_offers (if you put it directly on the interactible)
	var direct: Array[ShopOffer] = _try_get_shop_offers_from_object(planet)
	if direct.size() > 0:
		return direct

	# 2) planet.dialogue_data.shop_offers
	var data: Variant = _safe_get(planet, &"dialogue_data")
	if data is Object:
		var from_dialogue_data: Array[ShopOffer] = _try_get_shop_offers_from_object(data as Object)
		if from_dialogue_data.size() > 0:
			return from_dialogue_data

		# 3) planet.dialogue_data.npc_data.shop_offers
		var nd: Variant = _safe_get(data as Object, &"npc_data")
		if nd is Object:
			var from_nested_npc: Array[ShopOffer] = _try_get_shop_offers_from_object(nd as Object)
			if from_nested_npc.size() > 0:
				return from_nested_npc

	# 4) planet.npc_data.shop_offers
	var npc_data: Variant = _safe_get(planet, &"npc_data")
	if npc_data is Object:
		var from_npc_data: Array[ShopOffer] = _try_get_shop_offers_from_object(npc_data as Object)
		if from_npc_data.size() > 0:
			return from_npc_data

	# 5) planet.get_shop_offers()
	if planet.has_method("get_shop_offers"):
		var v: Variant = planet.call("get_shop_offers")
		var arr: Array[ShopOffer] = _cast_shop_offer_array(v)
		if arr.size() > 0:
			return arr

	# 6) legacy fallback: get_shop_items + get_shop_prices
	var legacy: Array[ShopOffer] = _legacy_offers_from_planet(planet)
	if legacy.size() > 0:
		return legacy

	return []


func _try_get_shop_offers_from_object(obj: Object) -> Array[ShopOffer]:
	if obj == null:
		return []

	# Property: obj.shop_offers
	var v: Variant = _safe_get(obj, &"shop_offers")
	var arr: Array[ShopOffer] = _cast_shop_offer_array(v)
	if arr.size() > 0:
		return arr

	# Method: obj.get_shop_offers()
	if obj.has_method("get_shop_offers"):
		var v2: Variant = obj.call("get_shop_offers")
		var arr2: Array[ShopOffer] = _cast_shop_offer_array(v2)
		if arr2.size() > 0:
			return arr2

	return []


func _cast_shop_offer_array(v: Variant) -> Array[ShopOffer]:
	var out: Array[ShopOffer] = []
	if v is Array:
		var a: Array = v as Array
		for i: int in range(0, a.size()):
			var e: Variant = a[i]
			if e is ShopOffer:
				out.append(e as ShopOffer)
	return out


func _legacy_offers_from_planet(planet: Node) -> Array[ShopOffer]:
	if planet == null or not is_instance_valid(planet):
		return []

	if planet.has_method("get_shop_items") == false:
		return []

	var items_any: Variant = planet.call("get_shop_items")
	var prices_any: Variant = []
	if planet.has_method("get_shop_prices"):
		prices_any = planet.call("get_shop_prices")

	if (items_any is Array) == false or (prices_any is Array) == false:
		return []

	var items: Array = items_any as Array
	var prices: Array = prices_any as Array

	var max_len: int = items.size()
	if prices.size() < max_len:
		max_len = prices.size()

	var fallback: Array[ShopOffer] = []
	for i: int in range(0, max_len):
		var fake_item: ShopItemData = ShopItemData.new()
		fake_item.display_name = String(items[i])
		fake_item.description = ""
		fake_item.icon = null

		var offer: ShopOffer = ShopOffer.new()
		offer.item = fake_item
		offer.price = int(prices[i])
		offer.stock = -1
		fallback.append(offer)

	return fallback


# -------------------------------------------------------------------
# UI building
# -------------------------------------------------------------------

func _build_rows(offers: Array[ShopOffer]) -> void:
	if row_scene == null:
		push_warning("[SHOP] row_scene is null. Assign ShopItemRow.tscn.")
		return

	for i: int in range(0, offers.size()):
		var node: Node = row_scene.instantiate()
		var row: ShopItemRow = node as ShopItemRow
		if row == null:
			push_warning("[SHOP] row_scene root is not ShopItemRow.")
			node.queue_free()
			continue

		shop_rows_parent.add_child(row)
		_rows.append(row)

		row.setup(i, offers[i])
		row.pressed.connect(_on_row_pressed)


func _clear_rows() -> void:
	_selected_index = -1
	_offers.clear()
	_rows.clear()

	if shop_rows_parent == null:
		return

	for child: Node in shop_rows_parent.get_children():
		child.queue_free()


func _on_row_pressed(idx: int) -> void:
	_set_selected_index(idx)
	_update_buy_button_state()


func _set_selected_index(idx: int) -> void:
	_selected_index = idx
	for i: int in range(0, _rows.size()):
		_rows[i].set_selected(i == _selected_index)

func _update_buy_button_state() -> void:
	if buy_button == null:
		return

	if _selected_index < 0 or _selected_index >= _offers.size():
		buy_button.disabled = true
		return

	var offer: ShopOffer = _offers[_selected_index]
	if offer == null or not offer.is_available():
		buy_button.disabled = true
		return

	# If unique and already owned, disable
	if offer.item is ShopItemData:
		var item: ShopItemData = offer.item as ShopItemData
		if item != null and item.unique:
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree != null:
				var inv: ShopInventory = tree.root.get_node_or_null("ShopInventory") as ShopInventory
				if inv != null and inv.has_unique(item.id):
					buy_button.disabled = true
					return

	var have: int = _get_currency_amount()
	buy_button.disabled = have < offer.price



func _on_buy_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _offers.size():
		return

	var offer: ShopOffer = _offers[_selected_index]
	if offer == null or not offer.is_available():
		return

	if _try_spend_currency(offer.price) == false:
		print("[SHOP] Not enough ", currency_id, " (need ", offer.price, ", have ", _get_currency_amount(), ")")
		_update_buy_button_state()
		return
	print("[SHOP] item class=", offer.item.get_class())
	print("[SHOP] resource_path=", offer.item.resource_path)
	
	# NEW: polymorphic purchase behavior (ShopItemData decides what happens)
	var applied: bool = false
	if offer.item is ShopItemData:
		var item: ShopItemData = offer.item as ShopItemData
		applied = item.apply_purchase(1, _planet)
		var scr: Script = null
		if item != null:
			scr = item.get_script()

		print("[SHOP DBG] item=", item)
		print("[SHOP DBG] item path=", (item.resource_path if item != null else "null"))
		print("[SHOP DBG] is ShopItemData=", (item is ShopItemData))
		print("[SHOP DBG] is PassiveShopItemData=", (item is PassiveShopItemData))
		print("[SHOP DBG] script=", scr)
		print("[SHOP DBG] script path=", (scr.resource_path if scr != null else "null"))
		print("[SHOP DBG] has apply_purchase=", (item != null and item.has_method("apply_purchase")))

	# Legacy fallback (old behavior)
	if applied == false:
		_grant_item_to_player(offer)

	if offer.stock > 0:
		offer.stock -= 1

	if _selected_index >= 0 and _selected_index < _rows.size():
		_rows[_selected_index].setup(_selected_index, offer)

	_update_buy_button_state()



# -------------------------------------------------------------------
# Currency (ResourceManager)
# -------------------------------------------------------------------

func _get_currency_amount() -> int:
	if _resource_manager == null:
		return 0
	if _resource_manager.has_method("get_amount") == false:
		return 0
	var v: Variant = _resource_manager.call("get_amount", currency_id)
	return int(v)


func _try_spend_currency(amount: int) -> bool:
	if _resource_manager == null:
		return false
	if _resource_manager.has_method("spend") == false:
		return false
	var ok: Variant = _resource_manager.call("spend", currency_id, amount)
	return bool(ok)


# -------------------------------------------------------------------
# Deliver purchased item (hooks)
# -------------------------------------------------------------------

func _grant_item_to_player(offer: ShopOffer) -> void:
	if offer == null or offer.item == null:
		return

	# If you have an inventory node, try common APIs.
	if player_inventory != null and is_instance_valid(player_inventory):
		if player_inventory.has_method("add_item"):
			player_inventory.call("add_item", offer.item, 1)
			return
		if player_inventory.has_method("give_item"):
			player_inventory.call("give_item", offer.item, 1)
			return
		if player_inventory.has_method("add"):
			player_inventory.call("add", offer.item, 1)
			return

	# Or let planet handle it, if you wired that.
	if _planet != null and is_instance_valid(_planet) and _planet.has_method("on_shop_purchase"):
		_planet.call("on_shop_purchase", offer.item, 1, offer.price)
		return

	# Fallback
	print("[SHOP] Purchased: ", offer.item.display_name, " x1 (no inventory hook wired yet)")


# -------------------------------------------------------------------
# Safe get helpers (same as your dialogue controller)
# -------------------------------------------------------------------

func _has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	var props: Array = obj.get_property_list()
	for p in props:
		var d: Dictionary = p as Dictionary
		if d.has("name") and StringName(d["name"]) == prop:
			return true
	return false


func _safe_get(obj: Object, prop: StringName) -> Variant:
	if _has_property(obj, prop):
		return obj.get(str(prop))
	return null
