extends Control

## 原创序章(借鉴《王国之泪》"自星海降临/引路者低语/封印灾厄"的结构, 文案全原创)。
## 由 TitleScreen「开始新游戏」后进入; 播完置 opening_done 并存档, 进入世界。

var _lines: Array = []
var _idx: int = 0
var _active: bool = true
var _label: Label
var _orb: Label
var _t: float = 0.0
var _finished: bool = false

func _ready() -> void:
	_build()
	_assemble_lines()
	_show()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# 星点(装饰)
	for i in range(40):
		var s := Control.new()
		s.position = Vector2(randf() * 1280.0, randf() * 600.0)
		s.custom_minimum_size = Vector2(2, 2)
		var c := ColorRect.new()
		c.color = Color(1, 1, 1, randf() * 0.6 + 0.2)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s.add_child(c)
		add_child(s)

	# 降临的光之球
	_orb = Label.new()
	_orb.text = "✦"
	_orb.add_theme_font_size_override("font_size", 120)
	_orb.modulate = Color(1.0, 0.95, 0.7)
	_orb.position = Vector2(600, -120)
	_orb.size = Vector2(120, 120)
	add_child(_orb)

	# 标题卡
	var title := Label.new()
	title.text = "序章 · 星海降临"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(0.85, 0.9, 1.0)
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 50)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 0
	title.offset_right = 0
	add_child(title)

	# 字幕面板
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = -160
	panel.offset_bottom = -40
	add_child(panel)

	_label = Label.new()
	_label.position = Vector2(140, get_viewport_rect().size.y - 150 if false else 520)
	_label.size = Vector2(1000, 110)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 24)
	_label.modulate = Color(0.95, 0.97, 1.0)
	add_child(_label)

	var hint := Label.new()
	hint.text = "按 E / 空格 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.6, 0.65, 0.75)
	hint.position = Vector2(0, 700)
	hint.size = Vector2(1280, 30)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(hint)

func _assemble_lines() -> void:
	var nm: String = GameState.player_name if GameState.player_name != "" else "旅人"
	_lines = [
		"（星海之上，万古的寂静里，有一缕光忽然睁开了眼。）",
		nm + "，你自星辉中苏醒。记忆像碎掉的光，散落在风里。",
		"一缕温柔的声音在脑海响起——「我是辉光，被封印在星核深处的引路者。」",
		"「星澜大陆的光之灵兽，正被名为『黯潮』的阴影侵蚀。若光尽，万物将长眠不醒。」",
		"「我唤你而来，是要你重新点燃星辉。这只『炎尾狐』会陪你启程。」",
		"（一道光自云端垂落，将你轻轻送往星澜大陆的晨曦之中……）",
		"——冒险，开始。"
	]

func _show() -> void:
	if _idx >= _lines.size():
		_finish()
		return
	_label.text = _lines[_idx]

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	# 光球缓缓下降并轻微浮动
	_orb.position.y = lerp(_orb.position.y, 280.0, delta * 0.6) + sin(_t * 2.0) * 0.4
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		_idx += 1
		_show()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	GameState.opening_done = true
	GameState.story_stage = 1
	SaveManager.save_game()
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://world/World.tscn")
