extends Control

## 标题画面 / 主菜单 (main_scene)。
## 提供: 开始新游戏 / 继续游戏(有存档时) / 设置(全屏切换) / 退出。
## 原创IP《星澜物语》(STELLARA), 与任天堂/Game Freak 无关。

const WORLD_SCENE := "res://world/World.tscn"

var _new_game_confirm := false
var _confirm_timer := 0.0
var _btn_new: Button
var _btn_continue: Button
var _btn_settings: Button
var _btn_quit: Button

func _ready() -> void:
	_build()
	_focus_default()

func _build() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.16)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(440, 0)
	add_child(vb)

	var title := Label.new()
	title.text = "星澜物语"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.modulate = Color(0.92, 0.96, 1.0)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "STELLARA · 原创灵兽冒险"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.6, 0.7, 0.85)
	vb.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vb.add_child(spacer)

	_btn_new = _make_button("开始新游戏")
	_btn_new.pressed.connect(_on_new)
	vb.add_child(_btn_new)

	_btn_continue = _make_button("继续游戏")
	if SaveManager.has_save():
		_btn_continue.pressed.connect(_on_continue)
	else:
		_btn_continue.text = "继续游戏 (暂无存档)"
		_btn_continue.disabled = true
	vb.add_child(_btn_continue)

	_btn_settings = _make_button(_settings_label())
	_btn_settings.pressed.connect(_on_settings)
	vb.add_child(_btn_settings)

	_btn_quit = _make_button("退出")
	_btn_quit.pressed.connect(_on_quit)
	vb.add_child(_btn_quit)

	var hint := Label.new()
	hint.text = "WASD 移动 · 鼠标右键转视角 · 空格攻击/跳 · Shift 闪避 · E 交互 · B 遭遇 · C 收服 · Q 换人 · Esc 暂停"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.7, 0.7, 0.75)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(480, 40)
	vb.add_child(hint)

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 54)
	b.add_theme_font_size_override("font_size", 22)
	return b

func _focus_default() -> void:
	if _btn_continue and not _btn_continue.disabled:
		_btn_continue.grab_focus()
	else:
		_btn_new.grab_focus()

func _settings_label() -> String:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	return "设置: " + ("当前全屏 (点击切窗口)" if full else "当前窗口 (点击切全屏)")

func _on_new() -> void:
	if not _new_game_confirm:
		_new_game_confirm = true
		_confirm_timer = 3.0
		_btn_new.text = "确认开始新游戏? (再按一次将覆盖存档)"
		_btn_new.grab_focus()
		return
	GameState.reset_new_game()
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_continue() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_settings() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_btn_settings.text = _settings_label()
	_btn_settings.grab_focus()

func _on_quit() -> void:
	get_tree().quit()

func _process(delta: float) -> void:
	if _new_game_confirm:
		_confirm_timer -= delta
		if _confirm_timer <= 0.0:
			_new_game_confirm = false
			_btn_new.text = "开始新游戏"
