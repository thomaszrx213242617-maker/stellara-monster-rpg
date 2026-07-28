extends CanvasLayer

## 目标方向罗盘(原创IP《星澜物语》): 北向上方, 箭头指向当前目标相对玩家位置,
## 并显示直线距离。目标无效(零向量)时自动隐藏。不拦截鼠标输入。
## 优先级: GameState.objective_target(手动覆盖, 如序章) 非零则用; 否则按 current_objective_target() 推导。

var _arrow: Control
var _dist_label: Label
var _panel: Panel

func _ready() -> void:
	_build()
	layer = 20

func _build() -> void:
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(96, 96)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_right = -24
	_panel.offset_top = 24
	_panel.offset_left = -120
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.14, 0.78)
	sb.border_color = Color(0.5, 0.6, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(48)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var n := Label.new()
	n.text = "N"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 14)
	n.modulate = Color(0.8, 0.85, 1.0)
	n.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	n.offset_top = 6
	n.custom_minimum_size = Vector2(0, 18)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(n)

	_arrow = Control.new()
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_arrow.custom_minimum_size = Vector2(48, 48)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_arrow)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(0, -20), Vector2(13, 16), Vector2(-13, 16)])
	tri.color = Color(1.0, 0.85, 0.3)
	_arrow.add_child(tri)

	_dist_label = Label.new()
	_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dist_label.add_theme_font_size_override("font_size", 13)
	_dist_label.modulate = Color(0.85, 0.9, 0.96)
	_dist_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dist_label.offset_bottom = -6
	_dist_label.custom_minimum_size = Vector2(0, 18)
	_dist_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_dist_label)

func _process(_dt: float) -> void:
	if objective_target_invalid():
		_panel.visible = false
		return
	_panel.visible = true
	_arrow.rotation = deg_to_rad(get_bearing_deg())
	_dist_label.text = "%.0f m" % distance_to_target()

## 实际目标坐标: 手动覆盖优先, 否则按当前主线阶段推导
func target_pos() -> Vector3:
	if GameState.objective_target != Vector3.ZERO:
		return GameState.objective_target
	return GameState.current_objective_target()

func objective_target_invalid() -> bool:
	return target_pos() == Vector3.ZERO

## 北向上方位角(度, 顺时针): 0=正北(-Z), 90=正东(+X)
func get_bearing_deg() -> float:
	var t: Vector3 = target_pos()
	var dx: float = t.x - GameState.player_position.x
	var dz: float = t.z - GameState.player_position.z
	return rad_to_deg(atan2(dx, -dz))

func distance_to_target() -> float:
	var t: Vector3 = target_pos()
	var dx: float = t.x - GameState.player_position.x
	var dz: float = t.z - GameState.player_position.z
	return sqrt(dx * dx + dz * dz)
