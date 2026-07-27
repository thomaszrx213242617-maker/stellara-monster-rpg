extends Control

## 进化演出覆盖层(原创IP《星澜物语》): 胜利结算时若灵兽进化, 先播放
## 「前形态 → 后形态」的辉光庆祝, 结束后 emit finished, 由战斗继续结算。
## 也可按 空格/E/Esc 提前跳过。

signal finished

var from_id: String = ""
var to_id: String = ""

var _done: bool = false

func _ready() -> void:
	_build()
	await get_tree().create_timer(3.8).timeout
	_finish()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var title := Label.new()
	title.text = "进 化 ！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.modulate = Color(1.0, 0.95, 0.6)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 70
	title.custom_minimum_size = Vector2(0, 70)
	add_child(title)

	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(720, 260)
	add_child(center)

	center.add_child(_creature_card(from_id, false))
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 64)
	arrow.modulate = Color(1.0, 0.9, 0.6)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size = Vector2(80, 0)
	center.add_child(arrow)
	center.add_child(_creature_card(to_id, true))

	var hint := Label.new()
	hint.text = "（按 空格 / E / Esc 跳过）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(0.8, 0.82, 0.9)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_bottom = -30
	hint.custom_minimum_size = Vector2(0, 26)
	add_child(hint)

	# 入场动画: 中央容器轻微放大 + 标题淡入
	center.scale = Vector2(0.85, 0.85)
	var t := create_tween()
	t.tween_property(center, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT)
	title.modulate.a = 0.0
	var t2 := create_tween()
	t2.tween_property(title, "modulate:a", 1.0, 0.6)

func _creature_card(id: String, glow: bool) -> Panel:
	var data: Dictionary = DataBus.get_creature(id)
	var tcolor: Color = DataBus.type_color(data.get("type", ""))
	var name: String = data.get("name", id)
	var ctype: String = data.get("type", "")

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(250, 230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.18)
	sb.border_color = tcolor
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	panel.add_child(vbox)

	# 灵兽本体: 属性色发光圆(造型化)
	var orb := Panel.new()
	orb.custom_minimum_size = Vector2(96, 96)
	var osb := StyleBoxFlat.new()
	osb.bg_color = tcolor
	osb.set_corner_radius_all(48)
	osb.set_shadow_color(tcolor)
	osb.set_shadow_size(16 if glow else 4)
	orb.add_theme_stylebox_override("panel", osb)
	vbox.add_child(orb)
	if glow:
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(orb, "scale", Vector2(1.12, 1.12), 0.7).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(orb, "scale", Vector2(1.0, 1.0), 0.7).set_ease(Tween.EASE_IN_OUT)

	var n := Label.new()
	n.text = name
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 28)
	n.modulate = Color(1.0, 1.0, 1.0)
	vbox.add_child(n)

	var tl := Label.new()
	tl.text = "属性 · " + ctype
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 16)
	tl.add_theme_color_override("font_color", tcolor)
	vbox.add_child(tl)

	return panel

func _unhandled_input(e: InputEvent) -> void:
	if _done:
		return
	if e.is_action_just_pressed("interact") or e.is_action_just_pressed("attack") \
		or e.is_action_just_pressed("ui_cancel") or e.is_action_just_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
