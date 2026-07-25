extends Control

## 商店面板(原创货币: 星辉币)。列出可购买道具(球类/伤药), 点击购买扣除货币。
## 由 World 在商店区按 E 打开; 打开时暂停场景树, 关闭时恢复。

var _world
var _panel: Panel
var _coins_label: Label
var _open: bool = false

func setup(world) -> void:
	_world = world
	_build()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 460)
	add_child(_panel)

	var title := Label.new()
	title.text = "星辉商栈"
	title.add_theme_font_size_override("font_size", 30)
	title.position = Vector2(20, 14)
	_panel.add_child(title)

	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 18)
	_coins_label.position = Vector2(20, 54)
	_panel.add_child(_coins_label)

	var vb := VBoxContainer.new()
	vb.position = Vector2(20, 90)
	vb.size = Vector2(520, 330)
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)

	for iid in GameState.shop_items():
		var it: Dictionary = DataBus.get_item(iid)
		var row := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = it["name"] + "  ×" + str(GameState.inventory.get(iid, 0))
		name_l.custom_minimum_size = Vector2(220, 0)
		name_l.add_theme_font_size_override("font_size", 16)
		row.add_child(name_l)
		var price_l := Label.new()
		price_l.text = str(it.get("price", 0)) + " 币"
		price_l.custom_minimum_size = Vector2(110, 0)
		price_l.add_theme_font_size_override("font_size", 16)
		row.add_child(price_l)
		var buy := Button.new()
		buy.text = "购买"
		buy.custom_minimum_size = Vector2(100, 34)
		var captured: String = iid
		buy.pressed.connect(func(): _buy(captured))
		row.add_child(buy)
		vb.add_child(row)

	var close := Button.new()
	close.text = "离开 (Esc)"
	close.custom_minimum_size = Vector2(200, 44)
	close.position = Vector2(180, 410)
	close.pressed.connect(close_shop)
	_panel.add_child(close)

func _buy(id: String) -> void:
	if GameState.buy_item(id, 1):
		_pop_coins()
		# 刷新列表中的持有数
		_rebuild_rows()
	else:
		_coins_label.text = "星辉币: " + str(GameState.coins) + "  (钱不够或无法购买)"

func _pop_coins() -> void:
	_coins_label.text = "星辉币: " + str(GameState.coins)

func _rebuild_rows() -> void:
	# 简单重建: 关闭再开以刷新持有数
	var was_open: bool = _open
	close_shop()
	if was_open:
		open_shop()

func open_shop() -> void:
	_open = true
	visible = true
	_pop_coins()
	if _world != null:
		get_tree().paused = true

func close_shop() -> void:
	_open = false
	visible = false
	if _world != null:
		get_tree().paused = false

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and _open:
		close_shop()
		get_viewport().set_input_as_handled()
