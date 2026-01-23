extends PanelContainer
class_name ShopItemRow

signal pressed(index: int)

@export var icon_rect: TextureRect
@export var price_label: Label
@export var availability_label: Label
@export var name_label: Label
@export var desc_label: RichTextLabel

var index: int = -1
var offer: ShopOffer = null

var _selected: bool = false

func setup(p_index: int, p_offer: ShopOffer) -> void:
	index = p_index
	offer = p_offer

	var item: ShopItemData = null
	if offer != null:
		item = offer.item

	if icon_rect != null:
		icon_rect.texture = item.icon if item != null else null

	if name_label != null:
		name_label.text = item.display_name if item != null else "(Missing Item)"

	if desc_label != null:
		desc_label.bbcode_enabled = false
		desc_label.text = item.description if item != null else ""

	if price_label != null:
		price_label.text = str(offer.price) + " scr" if offer != null else "—"

	if availability_label != null:
		availability_label.text = _availability_text(offer)

	_update_selected_visual()

func set_selected(v: bool) -> void:
	_selected = v
	_update_selected_visual()

func is_selected() -> bool:
	return _selected

func _availability_text(p_offer: ShopOffer) -> String:
	if p_offer == null:
		return "Unavailable"
	if p_offer.stock == -1:
		return "In stock"
	if p_offer.stock == 0:
		return "Sold out"
	return "Stock: " + str(p_offer.stock)

func _update_selected_visual() -> void:
	# Simple highlight without relying on theme overrides.
	# (If you want nicer visuals, use theme overrides or StyleBoxes.)
	modulate.a = 1.0
	if _selected:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.92, 0.92, 0.92, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit(index)
