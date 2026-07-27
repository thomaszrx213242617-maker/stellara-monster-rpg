extends Control

## 御三家选择画面(原创IP《星澜物语》): 玩家从 焰狐(炎)/碧蛙(水)/藤兔(木) 中择一。
## 选中后调用 GameState.choose_starter(id) 入队, 并进入开场动画 IntroCinematic。
## 操作: ← → 选择(也支持 A/D 与鼠标点击), 空格/回车/E 确定。

const INTRO_SCENE := "res://ui/IntroCinematic.tscn"
const STARTERS := ["flarefox", "aqualeap", "vinelop"]

var _idx: int = 0
var _cards: Array = []        # 三张 Panel
var _card_meta: Array = []    # 与 _cards 对应的灵兽 id
var _confirming: bool = false

func _ready() -> void:
	_build()
	_select(0)
	SoundBus.play_sfx("select")

func _build() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "选择你的初始灵兽"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(0.96, 0.98, 1.0)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 36
	title.custom_minimum_size = Vector2(0, 60)
	add_child(title)

	# 副标题
	var sub := Label.new()
	sub.text = "御三家 · 仅此一只，将陪伴你开启冒险"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.7, 0.78, 0.92)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 104
	sub.custom_minimum_size = Vector2(0, 28)
	add_child(sub)

	# 卡片行(水平居中, 位于屏幕中部)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.custom_minimum_size = Vector2(900, 380)
	row.position = Vector2(0, -10)
	add_child(row)

	for cid in STARTERS:
		var card := _make_card(cid)
		_cards.append(card)
		_card_meta.append(cid)
		row.add_child(card)

	# 底部提示
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "← → / A D 选择    空格 / 回车 / E 确定    也可直接点击卡片"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(0.78, 0.82, 0.9)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_bottom = -28
	hint.custom_minimum_size = Vector2(0, 30)
	add_child(hint)

func _make_card(id: String) -> Panel:
	var data: Dictionary = DataBus.get_creature(id)
	var tcolor: Color = DataBus.type_color(data.get("type", ""))
	var name: String = data.get("name", id)
	var ctype: String = data.get("type", "")
	var ability: String = data.get("ability", "—")

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(260, 360)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.13, 0.22)
	normal.border_color = Color(0.25, 0.3, 0.45)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", normal)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18
	vbox.offset_right = -18
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	panel.add_child(vbox)

	# 名称
	var n := Label.new()
	n.text = name
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 30)
	n.modulate = Color(1.0, 1.0, 1.0)
	vbox.add_child(n)

	# 属性药丸
	var type_l := Label.new()
	type_l.text = "属性 · " + ctype
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_l.add_theme_font_size_override("font_size", 18)
	type_l.add_theme_color_override("font_color", tcolor)
	vbox.add_child(type_l)

	# 特性
	var ab := Label.new()
	ab.text = "特性 · " + ability
	ab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ab.add_theme_font_size_override("font_size", 15)
	ab.modulate = Color(0.8, 0.82, 0.9)
	vbox.add_child(ab)

	# 种族值条
	var stats: Dictionary = data.get("base", {})
	for sname in ["hp", "atk", "def", "spatk", "spdef", "spd"]:
		vbox.add_child(_stat_row(sname.to_upper(), int(stats.get(sname, 1)), 120, tcolor))

	# 进化
	var evo_to: String = data.get("evolve_to", "")
	var evo_lv: int = int(data.get("evolve_level", 0))
	if evo_to != "":
		var ed: Dictionary = DataBus.get_creature(evo_to)
		var evo_l := Label.new()
		evo_l.text = "进化 · Lv%d → %s" % [evo_lv, ed.get("name", evo_to)]
		evo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		evo_l.add_theme_font_size_override("font_size", 14)
		evo_l.modulate = Color(0.9, 0.85, 0.5)
		vbox.add_child(evo_l)

	# 简介
	var desc := Label.new()
	desc.text = data.get("desc", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(0.72, 0.76, 0.85)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# 点击: 选中并确认
	panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			var i: int = _card_meta.find(id)
			if i >= 0:
				_select(i)
				_confirm()
	)
	return panel

func _stat_row(label: String, value: int, maxv: int, color: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(0.8, 0.83, 0.9)
	l.custom_minimum_size = Vector2(34, 0)
	hb.add_child(l)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxv
	bar.value = value
	bar.custom_minimum_size = Vector2(150, 12)
	bar.show_percentage = false
	bar.add_theme_color_override("fill", color)
	hb.add_child(bar)
	var v := Label.new()
	v.text = str(value)
	v.add_theme_font_size_override("font_size", 12)
	v.modulate = Color(0.85, 0.88, 0.95)
	hb.add_child(v)
	return hb

func _select(i: int) -> void:
	_idx = posmod(i, _cards.size())
	for k in range(_cards.size()):
		var panel: Panel = _cards[k]
		var data: Dictionary = DataBus.get_creature(_card_meta[k])
		var tcolor: Color = DataBus.type_color(data.get("type", ""))
		var sb: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		if k == _idx:
			sb.border_color = tcolor
			sb.set_border_width_all(4)
			panel.modulate = Color(1.15, 1.15, 1.15)
			panel.scale = Vector2(1.05, 1.05)
		else:
			sb.border_color = Color(0.25, 0.3, 0.45)
			sb.set_border_width_all(2)
			panel.modulate = Color(0.7, 0.7, 0.72)
			panel.scale = Vector2(1.0, 1.0)
		panel.add_theme_stylebox_override("panel", sb)
	if _idx != i and not _confirming:
		SoundBus.play_sfx("select")

func _unhandled_input(e: InputEvent) -> void:
	if _confirming:
		return
	if e.is_action_just_pressed("ui_left") or e.is_action_just_pressed("move_left"):
		_select(_idx - 1)
		get_viewport().set_input_as_handled()
	elif e.is_action_just_pressed("ui_right") or e.is_action_just_pressed("move_right"):
		_select(_idx + 1)
		get_viewport().set_input_as_handled()
	elif e.is_action_just_pressed("ui_accept") or e.is_action_just_pressed("interact") or e.is_action_just_pressed("attack"):
		_confirm()
		get_viewport().set_input_as_handled()

func _confirm() -> void:
	if _confirming:
		return
	_confirming = true
	var id: String = _card_meta[_idx]
	var ok: bool = GameState.choose_starter(id)
	SoundBus.play_sfx("levelup")
	var sd: Dictionary = DataBus.get_creature(id)
	var name: String = sd.get("name", id)
	# 短暂提示后进入开场动画
	var toast := Label.new()
	toast.text = "你选择了 " + name + "！启程吧——"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 26)
	toast.modulate = Color(1.0, 0.9, 0.5)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.custom_minimum_size = Vector2(600, 50)
	add_child(toast)
	if not ok:
		# 理论上不会触发(choose_starter 已校验); 兜底直接进入
		pass
	await get_tree().create_timer(0.9).timeout
	get_tree().change_scene_to_file(INTRO_SCENE)
