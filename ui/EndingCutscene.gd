extends Control

## 原创结局(借鉴《旷野之息》"苏醒的力量/大地重归翠色/引路者解脱"的结构, 文案全原创)。
## 剧情: 击败被黯潮吞没的伙伴凛(最终boss)与双生金属神兽, 全体训练家NPC倾巢助战,
## 收服双神兽、救回凛, 星澜大陆重归平衡。由终局链触发; 播完置 ending_done 并存档, 返回标题。

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
	BGM.play_track("ending")

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
	title.text = "终章 · 双生神兽与重燃的星辉"
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
	var nm: String = Game.player_name if Game.player_name != "" else "旅人"
	_lines = [
		"黯潮之主·凛轰然倒下。你伸手按住他胸口的暗痕：「回来吧，凛。这不是你。」",
		"金光自他体内渗出——被吞没的伙伴，终于挣脱黯潮的枷锁。",
		"可辉金龙与黯钢兽仍在狂暴。正当它们要再放大招，天际传来齐声呼喊——",
		"向导·岚、劲敌·岩、小岚、阿砂、馆主·岩心、暗潮使·玄、登山客·石……所有训练家倾巢而至！",
		"「这一战，我们陪你！」万千灵兽同时跃起，将双生神兽的杀招一一挡下。",
		nm + "乘势抛出至尊球——辉金龙与黯钢兽，终于归你所有。",
		"黯潮溃散，星辉自地脉深处重新流淌。凛揉着眼睛笑了：「下次探洞，可别再把我弄丢。」",
		"光之灵兽自长眠中睁眼，旷野重新披上翠色与繁花。这，是只属于你们的传说。"
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
	Game.ending_done = true
	Game.story_stage = 3
	Save.save_game()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://ui/TitleScreen.tscn")
