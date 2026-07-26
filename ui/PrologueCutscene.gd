extends Control

## 原创新序章: 从山洞归来后在自家苏醒, 结识新伙伴(巡林人小岚 / 劲敌阿砂),
## 辉光指引你重新踏上寻找凛与双神兽之路。由 OpeningCutscene 衔接进入; 播完进世界。

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
	bg.color = Color(0.10, 0.13, 0.18)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	for i in range(40):
		var s := Control.new()
		s.position = Vector2(randf() * 1280.0, randf() * 600.0)
		s.custom_minimum_size = Vector2(2, 2)
		var c := ColorRect.new()
		c.color = Color(1, 1, 1, randf() * 0.5 + 0.2)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s.add_child(c)
		add_child(s)

	_orb = Label.new()
	_orb.text = "✦"
	_orb.add_theme_font_size_override("font_size", 100)
	_orb.modulate = Color(0.85, 0.95, 1.0)
	_orb.position = Vector2(600, -120)
	_orb.size = Vector2(120, 120)
	add_child(_orb)

	var title := Label.new()
	title.text = "新序章 · 重燃的星辉"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(0.88, 0.92, 1.0)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 0
	title.offset_right = 0
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
	_label.modulate = Color(0.95, 0.97, 1.0)
	add_child(_label)

	var hint := Label.new()
	hint.text = "按 E / 空格 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.6, 0.65, 0.75)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position = Vector2(0, 700)
	hint.size = Vector2(1280, 30)
	add_child(hint)

func _assemble_lines() -> void:
	var nm: String = GameState.player_name if GameState.player_name != "" else "旅人"
	_lines = [
		"床边守着一位扎着绿巾的少女——「你终于醒了！我是小岚，村里的巡林人。」",
		"「你被冲上岸时，怀里还抱着那只炎尾狐。可你的伙伴凛……还有那两头金属神兽，都不见了。」",
		"这时门被推开，少年阿砂探进头：「听说冠军回来了？咱俩虽是劲敌，但这事上得并肩。」",
		"脑海里，辉光的声音轻轻响起：「黯潮并未散去。凛被它吞噬，才会化作『黯潮之主』。」",
		"「去北之路收服灵兽、变强，唤醒晨曦镇的暗潮使·玄，深渊的大门才会为你敞开。」",
		nm + "，拿起灵球。这一回，你要找回凛，也要救下那两头被污染的金属神兽。",
		"——冒险，再次开始。"
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
	_orb.position.y = lerp(_orb.position.y, 280.0, delta * 0.6) + sin(_t * 2.0) * 0.4
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		_idx += 1
		_show()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	GameState.prologue_done = true
	GameState.story_stage = 1
	GameState.complete_milestone("落地星澜，开启旅途")
	SaveManager.save_game()
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://world/World.tscn")
