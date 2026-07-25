extends Control

## 原创序章·崩塌: 双生神兽苏醒 → 并肩迎战 → 败北、山洞崩塌 → 灵兽全数消失 → 在家苏醒。
## 由 PrologueExplore(洞中探险) 衔接进入; 播完衔接 PrologueCutscene(新序章/新伙伴)。

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
	bg.color = Color(0.06, 0.04, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	for i in range(40):
		var s := Control.new()
		s.position = Vector2(randf() * 1280.0, randf() * 600.0)
		s.custom_minimum_size = Vector2(2, 2)
		var c := ColorRect.new()
		c.color = Color(1, 1, 1, randf() * 0.6 + 0.2)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s.add_child(c)
		add_child(s)

	_orb = Label.new()
	_orb.text = "✦"
	_orb.add_theme_font_size_override("font_size", 120)
	_orb.modulate = Color(1.0, 0.7, 0.5)
	_orb.position = Vector2(600, -120)
	_orb.size = Vector2(120, 120)
	add_child(_orb)

	var title := Label.new()
	title.text = "序章 · 双生神兽的怒吼"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(1.0, 0.85, 0.85)
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 50)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 0
	title.offset_right = 0
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
	_label.modulate = Color(0.97, 0.95, 0.95)
	add_child(_label)

	var hint := Label.new()
	hint.text = "按 E / 空格 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.7, 0.65, 0.65)
	hint.position = Vector2(0, 700)
	hint.size = Vector2(1280, 30)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(hint)

func _assemble_lines() -> void:
	var nm: String = GameState.player_name if GameState.player_name != "" else "旅人"
	_lines = [
		"你们踏入封印之地。忽然，洞窟深处亮起两双眼睛——辉金龙与黯钢兽，两头金属性封面神兽同时苏醒！",
		"「不好，它们被黯潮污染了！」凛抛出灵球，你也与最强的伙伴并肩迎战——",
		"然而神兽之力的洪流远超预料。双生神兽齐声咆哮，释放出毁天灭地的大招！",
		"山洞在金属风暴中崩塌。你最后看见的，是凛被一道暗光卷走……",
		"（再睁眼时，你躺在自家床上。窗外是星澜村熟悉的晨光。）",
		"（可你怀中空空——被神兽打败后，你身上的灵兽，全数消失了。）",
		nm + "，这一回，你要从零开始，找回凛，也救下那两头被污染的金属神兽。",
		"——新的旅程，从这里开始。"
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
	GameState.prologue_scout_done = false  # 新周目重置探险标记
	SaveManager.save_game()
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://ui/PrologueCutscene.tscn")
