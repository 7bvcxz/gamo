class_name PremiumShopView
extends VBoxContainer

## The Premium Shop (Step 59, the shopping bag at the bottom-left): optional
## real-money products, apart from hiring (in-game money, the Hire button)
## and from building (tap the ground). Each product from the catalog: its
## icon, name and what it does, the steps it climbs (x2 ... x32, the owned
## ones lit), the storefront's price and a Buy button. With no storefront
## connected -- the web, and Android until billing is a validated step --
## every product reads 'Coming soon', its button is off, and nothing is ever
## charged or granted: a tap here never touches the island.

signal purchase_requested(id: String)
signal restore_requested

var store: PremiumStore
var lib: SpriteLibrary
var intro: Label
var list: VBoxContainer
var note: Label
var restore_button: Button
## Per product id: {"buy": Button, "price": Label, "owned": Label, "steps": [Button]}.
var cards: Dictionary = {}


func setup(p_store: PremiumStore, p_lib: SpriteLibrary) -> void:
	store = p_store
	lib = p_lib
	name = "PremiumShopView"
	add_theme_constant_override("separation", 10)
	intro = PanelViews.label("", 16, true)
	intro.name = "Intro"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	list = VBoxContainer.new()
	list.name = "Products"
	list.add_theme_constant_override("separation", 10)
	add_child(list)
	note = PanelViews.label("", 15, true)
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	restore_button = Button.new()
	restore_button.name = "Restore"
	restore_button.focus_mode = Control.FOCUS_NONE
	restore_button.custom_minimum_size = Vector2(0, 48)
	restore_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	restore_button.pressed.connect(func() -> void: restore_requested.emit())
	add_child(restore_button)
	_build()
	refresh()


func _build() -> void:
	PanelViews.clear(list)
	cards.clear()
	for p: Dictionary in store.products():
		var id := String(p["id"])
		var card := PanelContainer.new()
		card.name = "Product_" + id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var icon := PanelViews.icon(lib, String(p.get("icon", "")), 64.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := PanelViews.label("", 22)
		title.name = "Name"
		col.add_child(title)
		var desc := PanelViews.label("", 15, true)
		desc.name = "Desc"
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)
		var chips := HBoxContainer.new()
		chips.name = "Steps"
		chips.add_theme_constant_override("separation", 6)
		var step_buttons: Array[Button] = []
		for m: int in store.steps(p):
			var chip := Button.new()
			chip.text = "×%d" % m
			chip.disabled = true
			chip.focus_mode = Control.FOCUS_NONE
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.custom_minimum_size = Vector2(48, 34)
			chip.add_theme_font_size_override("font_size", 15)
			chips.add_child(chip)
			step_buttons.append(chip)
		col.add_child(chips)
		var buy_row := HBoxContainer.new()
		buy_row.add_theme_constant_override("separation", 10)
		var owned := PanelViews.label("", 15, true)
		owned.name = "Owned"
		owned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		owned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_row.add_child(owned)
		var price := PanelViews.label("", 18)
		price.name = "Price"
		price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_row.add_child(price)
		var buy := Button.new()
		buy.name = "Buy"
		buy.focus_mode = Control.FOCUS_NONE
		buy.custom_minimum_size = Vector2(150, 52)
		buy.add_theme_font_size_override("font_size", 18)
		buy.pressed.connect(func() -> void: purchase_requested.emit(id))
		buy_row.add_child(buy)
		col.add_child(buy_row)
		row.add_child(col)
		card.add_child(row)
		list.add_child(card)
		cards[id] = {"card": card, "name": title, "desc": desc, "buy": buy, "price": price, "owned": owned, "steps": step_buttons}


## Every line again from the catalog and the storefront (a new language, the
## panel opening, a storefront answer).
func refresh() -> void:
	intro.text = tr("store.intro")
	for p: Dictionary in store.products():
		var id := String(p["id"])
		var c: Dictionary = cards.get(id, {})
		if c.is_empty():
			continue
		var st := store.state(id)
		(c["name"] as Label).text = tr(String(p.get("name", id)))
		(c["desc"] as Label).text = tr(String(p.get("desc", "")))
		var steps: Array = c["steps"]
		for i in steps.size():
			(steps[i] as Button).theme_type_variation = &"SelectedButton" if i < int(st["owned"]) else &""
		(c["owned"] as Label).text = tr("store.owned") % [int(st["owned"]), int(st["max"])]
		var price := c["price"] as Label
		price.text = String(st["price"])
		price.visible = st["price"] != ""
		var buy := c["buy"] as Button
		buy.disabled = not st["available"]
		buy.text = tr("store.buy") if st["available"] else tr(String(st["reason"]))
		buy.accessibility_name = "%s: %s" % [tr(String(p.get("name", id))), buy.text]
	note.text = tr("store.unavailable_note")
	note.visible = not store.storefront.available()
	restore_button.text = tr("store.restore")
	restore_button.disabled = not store.can_restore()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and store != null:
		refresh()
