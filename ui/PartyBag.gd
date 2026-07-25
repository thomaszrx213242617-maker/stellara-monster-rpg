extends Control

## 队伍/背包面板(全屏覆盖层)。由 PauseMenu 实例化并切换可见性。
## 左: 队伍列表(点击选中); 右: 选中成员详情(HP/种族值/招式) + 背包(野外使用伤药治疗)。

signal closed

const TYPE_COLORS := {
	"炎": Color(0.9, 0.3, 0.2), "水": Color(0.2, 0.4, 0.9), "木": Color(0.3, 0.7, 0.3),
	"雷": Color(0.9, 0.9, 0.2), "岩": Color(0.6, 0.5, 0.4), "风": Color(0.7, 0.9, 0.8),
	"光": Color(1.0, 0.95, 0.6), "暗": Color(0.3, 0.2, 0.4), "械": Color(0.7, 0.7, 0.75),
	"灵": Color(0.8, 0.6, 0.9), "金": Color(0.72, 0.75, 0.82)
}

var _team_list: VBoxContainer
var _detail: Control
var _bag_list: VBoxContainer
var _info_label: Label
var _selected_index: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
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
	title.text = "队伍 / 背包"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.95, 0.97, 1.0)
	top.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 18)
	_info_label.modulate = Color(0.8, 0.85, 0.95)
	top.add_child(_info_label)

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(110, 40)
	back.pressed.connect(_on_back)
	top.add_child(back)

	# 主体: 左右分栏
	var body := HSplitContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 64
	body.split_offset = 360
	add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)

	var team_title := Label.new()
	team_title.text = "出战队伍"
	team_title.add_theme_font_size_override("font_size", 20)
	team_title.modulate = Color(0.9, 0.92, 1.0)
	left.add_child(team_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_team_list = VBoxContainer.new()
	_team_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_team_list)

	# 右侧: 详情 + 背包
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	_detail = Control.new()
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail)

	var bag_title := Label.new()
	bag_title.text = "背包 (野外可用伤药治疗)"
	bag_title.add_theme_font_size_override("font_size", 20)
	bag_title.modulate = Color(0.9, 0.92, 1.0)
	right.add_child(bag_title)

	var bag_scroll := ScrollContainer.new()
	bag_scroll.custom_minimum_size = Vector2(0, 150)
	right.add_child(bag_scroll)
	_bag_list = VBoxContainer.new()
	_bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_scroll.add_child(_bag_list)

	_refresh()
	if not GameState.team.is_empty():
		_select(0)

func _refresh() -> void:
	# 清空
	for ch in _team_list.get_children():
		ch.queue_free()
	for ch in _bag_list.get_children():
		ch.queue_free()
	_selected_index = -1

	_info_label.text = "队伍 %d/6 · 存储 %d" % [GameState.team.size(), GameState.storage.size()]

	for i in range(GameState.team.size()):
		var c: Dictionary = GameState.team[i]
		var d: Dictionary = DataBus.get_creature(c["id"])
		var nm: String = d.get("name", c["id"])
		var hp: int = int(c["hp"])
		var mhp: int = int(c["max_hp"])
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 44)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s  Lv%d  HP %d/%d" % [nm, int(c["level"]), hp, mhp]
		row.pressed.connect(_on_row_pressed.bind(i))
		_team_list.add_child(row)

	# 背包
	for id in GameState.inventory.keys():
		var it: Dictionary = DataBus.get_item(id)
		var n: int = int(GameState.inventory[id])
		var nm: String = it.get("name", id) if not it.is_empty() else id
		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.text = "%s ×%d" % [nm, n]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)
		if it.get("type", "") == "heal" and n > 0:
			var use_btn := Button.new()
			use_btn.text = "治疗"
			use_btn.custom_minimum_size = Vector2(90, 32)
			use_btn.pressed.connect(_on_use_item.bind(id))
			hb.add_child(use_btn)
		_bag_list.add_child(hb)

	if not GameState.team.is_empty():
		_select(0)

func _on_row_pressed(i: int) -> void:
	_select(i)

func _select(i: int) -> void:
	if i < 0 or i >= GameState.team.size():
		return
	_selected_index = i
	_draw_detail(i)

func _draw_detail(i: int) -> void:
	for ch in _detail.get_children():
		ch.queue_free()
	var c: Dictionary = GameState.team[i]
	var d: Dictionary = DataBus.get_creature(c["id"])
	var nm: String = d.get("name", c["id"])
	var ty: String = d.get("type", "")
	var hp: int = int(c["hp"])
	var mhp: int = int(c["max_hp"])

	# 头像(按属性上色)
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.color = TYPE_COLORS.get(ty, Color(0.8, 0.8, 0.8))
	portrait.position = Vector2(24, 16)
	_detail.add_child(portrait)

	var name_l := Label.new()
	name_l.text = "%s  Lv%d" % [nm, int(c["level"])]
	name_l.position = Vector2(160, 18)
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.modulate = Color(1.0, 1.0, 1.0)
	_detail.add_child(name_l)

	var type_l := Label.new()
	type_l.text = "属性: " + ty
	type_l.position = Vector2(160, 52)
	type_l.modulate = Color(0.85, 0.88, 0.95)
	_detail.add_child(type_l)

	# HP 条
	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.position = Vector2(160, 82)
	_detail.add_child(hp_label)
	var hp_bar := ProgressBar.new()
	hp_bar.position = Vector2(210, 82)
	hp_bar.custom_minimum_size = Vector2(200, 18)
	hp_bar.max_value = float(max(mhp, 1))
	hp_bar.value = float(hp)
	hp_bar.show_percentage = false
	_detail.add_child(hp_bar)

	# 种族值
	var base: Dictionary = d.get("base", {})
	var stat_y := 120
	for key in ["hp", "atk", "def", "spatk", "spdef", "spd"]:
		var sv: int = int(base.get(key, 0))
		var kl := Label.new()
		kl.text = key.to_upper()
		kl.position = Vector2(24, stat_y)
		kl.custom_minimum_size = Vector2(60, 0)
		kl.modulate = Color(0.8, 0.85, 0.95)
		_detail.add_child(kl)
		var bar := ProgressBar.new()
		bar.position = Vector2(88, stat_y)
		bar.custom_minimum_size = Vector2(180, 16)
		bar.max_value = 130.0
		bar.value = float(sv)
		bar.show_percentage = false
		_detail.add_child(bar)
		var vl := Label.new()
		vl.text = str(sv)
		vl.position = Vector2(276, stat_y)
		_detail.add_child(vl)
		stat_y += 28

	# 招式
	var mv_y := stat_y + 8
	var ml := Label.new()
	ml.text = "招式: " + ", ".join(_move_names(c.get("moves", [])))
	ml.position = Vector2(24, mv_y)
	ml.custom_minimum_size = Vector2(360, 0)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.modulate = Color(0.85, 0.88, 0.95)
	_detail.add_child(ml)

func _move_names(moves: Array) -> Array:
	var out := []
	for m in moves:
		var md: Dictionary = DataBus.get_move(m)
		out.append(md.get("name", m) if not md.is_empty() else m)
	return out

func _on_use_item(id: String) -> void:
	if _selected_index < 0 or _selected_index >= GameState.team.size():
		return
	if int(GameState.inventory.get(id, 0)) <= 0:
		return
	var c: Dictionary = GameState.team[_selected_index]
	var mhp: int = int(c["max_hp"])
	var before: int = int(c["hp"])
	var after: int = mini(mhp, before + 20)
	c["hp"] = after
	GameState.consume_item(id, 1)
	GameState.team_changed.emit()
	_refresh()
	_select(_selected_index)

func _on_back() -> void:
	closed.emit()
