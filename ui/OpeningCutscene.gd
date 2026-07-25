extends Control

## 原创序章(借鉴《王国之泪》"自星海降临/引路者低语/封印灾厄"的结构, 文案全原创)。
## 剧情: 你是星辉冠军(拥有全灵兽, 含金属性神兽)→与伙伴凛探山洞→遇双封面神兽(辉金龙/黯钢兽)→失败、山洞崩毁→在家苏醒、伙伴与神兽失踪。
## 由 TitleScreen「开始新游戏」后进入; 播完衔接 PrologueCutscene(新序章), 再进世界。

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
	title.text = "序章 · 星辉冠军与沉眠之洞"
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
		nm + "，你是星澜大陆的星辉冠军——历代最强的灵兽训练家，连金属性的神兽都听你号令。",
		"伙伴『凛』拍了拍你的肩：「山脊后面新发现了一道沉眠之洞，传说是双生神兽的封印。去看看？」",
		"你们举着火把走入洞中。岩壁上映着两道古老的刻痕——一龙，一兽，皆泛着金属的光泽。",
		"忽然，洞窟深处亮起两双眼睛。辉金龙与黯钢兽，两头金属性封面神兽同时苏醒！",
		"「不好，它们被黯潮污染了！」凛抛出灵球，你也与最强的伙伴并肩迎战——",
		"然而神兽之力的洪流远超预料。双生神兽齐声咆哮，释放出毁天灭地的大招！",
		"山洞在金属风暴中崩塌。你最后看见的，是凛被一道暗光卷走……",
		"（再睁眼时，你躺在自家床上。窗外是星澜村熟悉的晨光。凛，和那两头神兽，都不见了。）",
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
	SaveManager.save_game()
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://ui/PrologueCutscene.tscn")
