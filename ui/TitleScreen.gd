extends Control

## 标题画面 / 主菜单 (main_scene)。
## 流程: 开始新游戏 → 填写名字/性别 → 序章(OpeningCutscene) → 世界。
## 继续游戏: 直接进世界(身份从存档读取)。
## 原创IP《星澜物语》(STELLARA), 与任天堂/Game Freak 无关。

const WORLD_SCENE := "res://world/World.tscn"
const OPENING_SCENE := "res://ui/OpeningCutscene.tscn"

var _menu: VBoxContainer
var _setup: VBoxContainer
var _name_edit: LineEdit
var _gender: String = "少年"
var _btn_boy: Button
var _btn_girl: Button
var _btn_continue: Button

func _ready() -> void:
	_build()
	_menu.visible = true
	_setup.visible = false
	_focus_default()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.16)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# ---- 主菜单 ----
	_menu = VBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.custom_minimum_size = Vector2(460, 0)
	add_child(_menu)

	var title := Label.new()
	title.text = "星澜物语"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.modulate = Color(0.92, 0.96, 1.0)
	_menu.add_child(title)

	var sub := Label.new()
	sub.text = "STELLARA · 原创灵兽冒险"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.6, 0.7, 0.85)
	_menu.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	_menu.add_child(spacer)

	var b_new := _make_button("开始新游戏")
	b_new.pressed.connect(_on_new)
	_menu.add_child(b_new)

	_btn_continue = _make_button("继续游戏")
	if SaveManager.has_save():
		_btn_continue.pressed.connect(_on_continue)
	else:
		_btn_continue.text = "继续游戏 (暂无存档)"
		_btn_continue.disabled = true
	_menu.add_child(_btn_continue)

	var b_settings := _make_button(_settings_label())
	b_settings.pressed.connect(_on_settings)
	_menu.add_child(b_settings)

	var b_quit := _make_button("退出")
	b_quit.pressed.connect(_on_quit)
	_menu.add_child(b_quit)

	var hint := Label.new()
	hint.text = "WASD 移动 · 鼠标右键转视角 · 空格攻击/跳 · Shift 闪避 · E 交互 · B 遭遇 · C 收服 · Q 换人 · Esc 暂停"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.7, 0.7, 0.75)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(480, 40)
	_menu.add_child(hint)

	# ---- 创建角色面板 ----
	_setup = VBoxContainer.new()
	_setup.alignment = BoxContainer.ALIGNMENT_CENTER
	_setup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_setup.custom_minimum_size = Vector2(460, 0)
	add_child(_setup)

	var t2 := Label.new()
	t2.text = "创建你的冒险者"
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 36)
	t2.modulate = Color(0.95, 0.97, 1.0)
	_setup.add_child(t2)

	var warn := Label.new()
	warn.text = "（这将开始新游戏，覆盖已有存档）"
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 14)
	warn.modulate = Color(0.9, 0.6, 0.6)
	_setup.add_child(warn)

	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 16)
	_setup.add_child(sp2)

	var lname := Label.new()
	lname.text = "名字"
	lname.add_theme_font_size_override("font_size", 18)
	lname.modulate = Color(0.85, 0.88, 0.95)
	_setup.add_child(lname)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "输入你的名字（默认：旅人）"
	_name_edit.custom_minimum_size = Vector2(360, 40)
	_name_edit.max_length = 12
	_setup.add_child(_name_edit)

	var lgen := Label.new()
	lgen.text = "性别"
	lgen.add_theme_font_size_override("font_size", 18)
	lgen.modulate = Color(0.85, 0.88, 0.95)
	_setup.add_child(lgen)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_boy = _make_button("少年")
	_btn_boy.pressed.connect(func(): _set_gender("少年"))
	_btn_girl = _make_button("少女")
	_btn_girl.pressed.connect(func(): _set_gender("少女"))
	hb.add_child(_btn_boy)
	hb.add_child(_btn_girl)
	_setup.add_child(hb)
	_set_gender("少年")

	var sp3 := Control.new()
	sp3.custom_minimum_size = Vector2(0, 12)
	_setup.add_child(sp3)

	var b_confirm := _make_button("确定，开始冒险")
	b_confirm.pressed.connect(_on_setup_confirm)
	_setup.add_child(b_confirm)

	var b_back := _make_button("返回")
	b_back.pressed.connect(_on_back_to_menu)
	_setup.add_child(b_back)

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 54)
	b.add_theme_font_size_override("font_size", 22)
	return b

func _set_gender(g: String) -> void:
	_gender = g
	_btn_boy.modulate = Color(1, 1, 1) if g == "少年" else Color(0.6, 0.6, 0.6)
	_btn_girl.modulate = Color(1, 1, 1) if g == "少女" else Color(0.6, 0.6, 0.6)
	_btn_boy.grab_focus() if g == "少年" else _btn_girl.grab_focus()

func _focus_default() -> void:
	if _btn_continue and not _btn_continue.disabled:
		_btn_continue.grab_focus()
	else:
		# 主菜单第一个按钮(开始新游戏)
		for c in _menu.get_children():
			if c is Button:
				c.grab_focus()
				break

func _settings_label() -> String:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	return "设置: " + ("当前全屏 (点击切窗口)" if full else "当前窗口 (点击切全屏)")

func _on_new() -> void:
	_menu.visible = false
	_setup.visible = true
	_name_edit.grab_focus()

func _on_back_to_menu() -> void:
	_setup.visible = false
	_menu.visible = true
	_focus_default()

func _on_setup_confirm() -> void:
	GameState.reset_new_game()
	GameState.set_player_identity(_name_edit.text, _gender)
	get_tree().change_scene_to_file(OPENING_SCENE)

func _on_continue() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_settings() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	for c in _menu.get_children():
		if c is Button and c.text.begins_with("设置"):
			c.text = _settings_label()
			c.grab_focus()

func _on_quit() -> void:
	get_tree().quit()
