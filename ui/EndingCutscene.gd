extends Control

## 原创结局(借鉴《旷野之息》"苏醒的力量/大地重归翠色/引路者解脱"的结构, 文案全原创)。
## 由 World 在终Boss击败后触发; 播完置 ending_done 并存档, 返回标题。

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
	bg.color = Color(0.18, 0.14, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	for i in range(40):
		var s := Control.new()
		s.position = Vector2(randf() * 1280.0, randf() * 600.0)
		s.custom_minimum_size = Vector2(2, 2)
		var c := ColorRect.new()
		c.color = Color(1.0, 0.95, 0.7, randf() * 0.6 + 0.3)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s.add_child(c)
		add_child(s)

	_orb = Label.new()
	_orb.text = "✦"
	_orb.add_theme_font_size_override("font_size", 140)
	_orb.modulate = Color(1.0, 0.9, 0.6)
	_orb.position = Vector2(600, 520)
	_orb.size = Vector2(140, 140)
	add_child(_orb)

	var title := Label.new()
	title.text = "终章 · 星辉重燃"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(1.0, 0.95, 0.8)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 50)
	add_child(title)

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = -160
	panel.offset_bottom = -40
	add_child(panel)

	_label = Label.new()
	_label.position = Vector2(140, 520)
	_label.size = Vector2(1000, 110)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 24)
	_label.modulate = Color(1.0, 0.97, 0.9)
	add_child(_label)

	var hint := Label.new()
	hint.text = "按 E / 空格 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.7, 0.65, 0.55)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position = Vector2(0, 700)
	hint.size = Vector2(1280, 30)
	add_child(hint)

func _assemble_lines() -> void:
	var nm: String = GameState.player_name if GameState.player_name != "" else "旅人"
	_lines = [
		"黯潮溃散，星辉自地脉深处重新流淌。",
		nm + "，你握住了星核。辉光的声音最后一次在你心中响起——",
		"「谢谢你。如今封印已破，我可以与这片大地一同，真正地苏醒。」",
		"光之灵兽自长眠中睁开眼，旷野重新披上翠色与繁花。",
		"你立于山巅，看星澜大陆在晨光里缓缓呼吸。",
		"——这，是只属于你们的传说。"
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
	_orb.position.y = lerp(_orb.position.y, 120.0, delta * 0.6) + sin(_t * 2.0) * 0.4
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		_idx += 1
		_show()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	GameState.ending_done = true
	GameState.story_stage = 3
	SaveManager.save_game()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://ui/TitleScreen.tscn")
