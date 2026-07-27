extends Control

## 可复用旁白框: 带淡入背景、漂浮微光粒子、脉动光球、打字机文字的过场叙事组件。
## 用法:
##   var n := NarrationBox.new()
##   add_child(n)
##   n.present(["第一行", "第二行"])
##   n.finished.connect(_on_narration_done)

signal finished

var _bg: ColorRect
var _panel: Panel
var _label: Label
var _hint: Label
var _orb: Label
var _title: Label
var _motes: Array = []   # {node, spd, drift}
var _lines: Array = []
var _idx: int = 0
var _char_t: float = 0.0
var _shown: int = 0
var _full_text: String = ""
var _done: bool = false
var _active: bool = true
var _t: float = 0.0

const TYPE_SPEED: float = 42.0  # 字符/秒

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.05, 0.04, 0.07)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.modulate = Color(1, 1, 1, 0.0)
	add_child(_bg)

	for i in range(44):
		var m := Control.new()
		m.position = Vector2(randf() * 1280.0, randf() * 720.0)
		m.custom_minimum_size = Vector2(2, 2)
		var c := ColorRect.new()
		c.color = Color(1, 1, 1, randf() * 0.5 + 0.2)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.add_child(c)
		add_child(m)
		_motes.append({"node": m, "spd": randf() * 16.0 + 6.0, "drift": randf() * 24.0 - 12.0})

	_orb = Label.new()
	_orb.text = "✦"
	_orb.add_theme_font_size_override("font_size", 120)
	_orb.modulate = Color(0.75, 0.85, 1.0)
	_orb.position = Vector2(580, -130)
	_orb.size = Vector2(120, 120)
	add_child(_orb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.modulate = Color(1.0, 0.85, 0.85, 0.0)
	_title.position = Vector2(0, 60)
	_title.size = Vector2(1280, 50)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 0
	_title.offset_right = 0
	add_child(_title)

	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 120
	_panel.offset_right = -120
	_panel.offset_top = -170
	_panel.offset_bottom = -40
	_panel.modulate = Color(1, 1, 1, 0.0)
	add_child(_panel)

	_label = Label.new()
	_label.position = Vector2(140, 520)
	_label.size = Vector2(1000, 120)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 24)
	_label.modulate = Color(0.97, 0.95, 0.95)
	add_child(_label)

	_hint = Label.new()
	_hint.text = "按 E / 空格 继续"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.position = Vector2(0, 700)
	_hint.size = Vector2(1280, 30)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.modulate = Color(0.7, 0.65, 0.65, 0.0)
	add_child(_hint)

func present(lines: Array, title: String = "") -> void:
	_lines = lines
	_idx = 0
	if title != "":
		_title.text = title
		_title.modulate.a = 0.0
	_show_line()

func _show_line() -> void:
	if _idx >= _lines.size():
		_finish()
		return
	_full_text = _lines[_idx]
	_shown = 0
	_char_t = 0.0
	_label.text = ""

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	# 背景 / 面板 / 提示 淡入
	_bg.modulate.a = min(1.0, _bg.modulate.a + delta * 2.0)
	_panel.modulate.a = min(0.92, _panel.modulate.a + delta * 2.0)
	_hint.modulate.a = min(0.7, _hint.modulate.a + delta * 1.5)
	if _title.text != "":
		_title.modulate.a = min(1.0, _title.modulate.a + delta * 1.5)
	# 光球脉动 + 漂浮
	_orb.position.y = lerp(_orb.position.y, 250.0, delta * 0.6) + sin(_t * 2.0) * 0.5
	_orb.modulate.a = 0.7 + sin(_t * 3.0) * 0.25
	# 微光上升
	for m in _motes:
		m["node"].position.y -= m["spd"] * delta
		m["node"].position.x += sin(_t + m["node"].position.y * 0.01) * m["drift"] * delta
		if m["node"].position.y < -4.0:
			m["node"].position.y = 724.0
			m["node"].position.x = randf() * 1280.0
	# 打字机
	if _shown < _full_text.length():
		_char_t += delta * TYPE_SPEED
		var n := int(_char_t)
		if n > _shown:
			_shown = mini(n, _full_text.length())
			_label.text = _full_text.substr(0, _shown)
	# 推进
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		if _shown < _full_text.length():
			_shown = _full_text.length()
			_label.text = _full_text
		else:
			_idx += 1
			_show_line()

func _finish() -> void:
	if _done:
		return
	_done = true
	_active = false
	finished.emit()
