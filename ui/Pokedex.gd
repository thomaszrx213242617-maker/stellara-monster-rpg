extends Control

## 灵兽图鉴面板(全屏覆盖层)。由 PauseMenu 实例化并切换可见性。
## 列出 data/creatures.json 中的全部灵兽, 按 已捕/已见/未知 三态区分显示信息。
## 已见即显示名称与属性; 已捕额外显示种族值与描述; 未知仅显示 ??? 剪影。

signal closed

const TYPE_COLORS := {
	"炎": Color(0.9, 0.3, 0.2), "水": Color(0.2, 0.4, 0.9), "木": Color(0.3, 0.7, 0.3),
	"雷": Color(0.9, 0.9, 0.2), "岩": Color(0.6, 0.5, 0.4), "风": Color(0.7, 0.9, 0.8),
	"光": Color(1.0, 0.95, 0.6), "暗": Color(0.3, 0.2, 0.4), "械": Color(0.7, 0.7, 0.75),
	"灵": Color(0.8, 0.6, 0.9), "金": Color(0.72, 0.75, 0.82)
}

var _list: VBoxContainer
var _detail: Control
var _prog_label: Label
var _entries: Array = []   # [{id, data, btn, seen, caught}]
var _selected_id := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	# 半透明深色底(挡住下层点击)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.1, 0.97)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 顶部栏
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.offset_bottom = 56
	add_child(top)

	var title := Label.new()
	title.text = "灵兽图鉴"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.95, 0.97, 1.0)
	top.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	_prog_label = Label.new()
	_prog_label.add_theme_font_size_override("font_size", 18)
	_prog_label.modulate = Color(0.8, 0.85, 0.95)
	top.add_child(_prog_label)

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(110, 40)
	back.pressed.connect(_on_back)
	top.add_child(back)

	# 左右分栏: 列表 | 详情
	var body := HSplitContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 64
	body.split_offset = 360
	add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	_detail = Control.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)

	_build_list()
	_refresh_progress()
	if not _entries.is_empty():
		_select(_entries[0]["id"])

func _build_list() -> void:
	for cid in DataBus.creatures.keys():
		var d: Dictionary = DataBus.creatures[cid]
		var seen: bool = GameState.dex_seen.has(cid)
		var caught: bool = GameState.dex_caught.has(cid)
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 44)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mark: String = "✓" if caught else ("○" if seen else "?")
		var nm: String = d.get("name", "") if seen else "？？？"
		var ty: String = d.get("type", "") if seen else ""
		row.text = mark + "  " + nm + (("  [" + ty + "]") if ty != "" else "")
		row.pressed.connect(_on_row_pressed.bind(cid))
		_list.add_child(row)
		_entries.append({"id": cid, "data": d, "btn": row, "seen": seen, "caught": caught})

func _on_row_pressed(id: String) -> void:
	_select(id)

func _select(id: String) -> void:
	_selected_id = id
	_draw_detail(id)

func _draw_detail(id: String) -> void:
	for ch in _detail.get_children():
		ch.queue_free()
	var d: Dictionary = DataBus.creatures.get(id, {})
	var seen: bool = GameState.dex_seen.has(id)
	var caught: bool = GameState.dex_caught.has(id)

	# 头像(按属性上色; 未知为暗剪影)
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(150, 150)
	var ty: String = d.get("type", "")
	var col: Color = TYPE_COLORS.get(ty, Color(0.8, 0.8, 0.8)) if seen else Color(0.12, 0.12, 0.16)
	portrait.color = col
	portrait.position = Vector2(24, 20)
	_detail.add_child(portrait)

	var nm: String = d.get("name", "") if seen else "？？？"
	var name_l := Label.new()
	name_l.text = nm
	name_l.position = Vector2(190, 24)
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.modulate = Color(1.0, 1.0, 1.0)
	_detail.add_child(name_l)

	var type_l := Label.new()
	type_l.text = ("属性: " + ty) if seen else "属性: 未知"
	type_l.position = Vector2(190, 60)
	type_l.add_theme_font_size_override("font_size", 18)
	type_l.modulate = Color(0.85, 0.88, 0.95)
	_detail.add_child(type_l)

	var state_l := Label.new()
	state_l.text = "✓ 已收服" if caught else ("○ 已发现(未收服)" if seen else "? 未发现")
	state_l.position = Vector2(190, 88)
	state_l.add_theme_font_size_override("font_size", 16)
	state_l.modulate = Color(0.7, 0.9, 0.7) if caught else (Color(0.9, 0.85, 0.6) if seen else Color(0.6, 0.6, 0.7))
	_detail.add_child(state_l)

	# 种族值
	var base: Dictionary = d.get("base", {})
	var stat_y := 140
	if seen and not base.is_empty():
		for key in ["hp", "atk", "def", "spatk", "spdef", "spd"]:
			_stat_row(key, int(base.get(key, 0)), Vector2(24, stat_y))
			stat_y += 34
	else:
		var unk := Label.new()
		unk.text = "（未发现，无法查看详细数据）"
		unk.position = Vector2(24, stat_y)
		unk.modulate = Color(0.6, 0.6, 0.7)
		_detail.add_child(unk)
		stat_y += 30

	# 描述
	var desc: String = ""
	if caught:
		desc = d.get("desc", "（暂无描述）")
	elif seen:
		desc = "（尚未收服，资料待补全）"
	else:
		desc = "（未发现）"
	var desc_l := Label.new()
	desc_l.text = desc
	desc_l.position = Vector2(24, stat_y + 12)
	desc_l.custom_minimum_size = Vector2(360, 0)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_l.modulate = Color(0.85, 0.88, 0.95)
	_detail.add_child(desc_l)

func _stat_row(key: String, val: int, pos: Vector2) -> void:
	var name_l := Label.new()
	name_l.text = key.to_upper()
	name_l.position = pos
	name_l.custom_minimum_size = Vector2(60, 0)
	name_l.modulate = Color(0.8, 0.85, 0.95)
	_detail.add_child(name_l)

	var bar := ProgressBar.new()
	bar.position = Vector2(pos.x + 64, pos.y)
	bar.custom_minimum_size = Vector2(220, 18)
	bar.max_value = 130.0
	bar.value = float(val)
	bar.show_percentage = false
	_detail.add_child(bar)

	var val_l := Label.new()
	val_l.text = str(val)
	val_l.position = Vector2(pos.x + 292, pos.y)
	val_l.modulate = Color(0.9, 0.92, 1.0)
	_detail.add_child(val_l)

func _refresh_progress() -> void:
	if _prog_label:
		_prog_label.text = "已捕 %d/%d  ·  已见 %d/%d" % [
			GameState.dex_caught_count(), GameState.dex_total(),
			GameState.dex_seen_count(), GameState.dex_total()
		]

func _on_back() -> void:
	closed.emit()
