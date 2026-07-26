extends CanvasLayer

## 世界内的暂停菜单(覆盖层)。挂在 World 下。
## 以 process_mode=PROCESS 存活, 即使场景树暂停也能响应输入(关闭/保存/返回标题)。
## 单一 Esc 处理入口: 未暂停时按 Esc 打开, 已暂停时按 Esc 关闭, 避免重复触发。

var _world
var _panel: Control
var _open := false
var _resume_btn: Button
var _dex
var _dex_open := false
var _party
var _party_open := false
var _settings
var _settings_open := false
const SettingsMenuScript := preload("res://ui/SettingsMenu.gd")
const PokedexScript := preload("res://ui/Pokedex.gd")
const PartyScript := preload("res://ui/PartyBag.gd")

func setup(world) -> void:
	_world = world
	_build()
	visible = false

func _build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 半透明遮罩(挡住下层点击)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(360, 0)
	add_child(vb)

	var t := Label.new()
	t.text = "已暂停"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.modulate = Color(0.95, 0.97, 1.0)
	vb.add_child(t)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vb.add_child(spacer)

	_resume_btn = _btn("继续游戏")
	_resume_btn.pressed.connect(_resume)
	vb.add_child(_resume_btn)

	var b_save := _btn("保存进度")
	b_save.pressed.connect(_save)
	vb.add_child(b_save)

	var b_title := _btn("返回标题")
	b_title.pressed.connect(_to_title)
	vb.add_child(b_title)

	var b_dex := _btn("灵兽图鉴")
	b_dex.pressed.connect(_open_dex)
	vb.add_child(b_dex)

	var b_party := _btn("队伍 / 背包")
	b_party.pressed.connect(_open_party)
	vb.add_child(b_party)

	var b_settings := _btn("设置")
	b_settings.pressed.connect(_open_settings)
	vb.add_child(b_settings)

	_panel = vb

func _btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 50)
	b.add_theme_font_size_override("font_size", 20)
	return b

func open() -> void:
	_open = true
	visible = true
	_resume_btn.grab_focus()

func close() -> void:
	_open = false
	visible = false
	_dex_open = false
	_party_open = false
	if _dex != null:
		_dex.visible = false
	if _party != null:
		_party.visible = false
	_panel.visible = true

func _open_dex() -> void:
	SoundBus.play_sfx("select")
	if _dex == null:
		_dex = PokedexScript.new()
		_dex.name = "Pokedex"
		add_child(_dex)
		_dex.closed.connect(_on_dex_closed)
	_dex.visible = true
	_panel.visible = false
	_dex_open = true

func _on_dex_closed() -> void:
	if _dex != null:
		_dex.visible = false
	_panel.visible = true
	_dex_open = false
	_resume_btn.grab_focus()

func _open_party() -> void:
	SoundBus.play_sfx("select")
	if _party == null:
		_party = PartyScript.new()
		_party.name = "PartyBag"
		add_child(_party)
		_party.closed.connect(_on_party_closed)
	_party.visible = true
	_panel.visible = false
	_party_open = true

func _on_party_closed() -> void:
	if _party != null:
		_party.visible = false
		_panel.visible = true
	_party_open = false
	_resume_btn.grab_focus()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if _settings_open:
			_on_settings_closed()
		elif _dex_open:
			_on_dex_closed()
		elif _party_open:
			_on_party_closed()
		elif _open:
			_world.resume_from_pause()
		else:
			_world.open_pause()
		get_viewport().set_input_as_handled()

func _resume() -> void:
	SoundBus.play_sfx("select")
	_world.resume_from_pause()

func _save() -> void:
	SoundBus.play_sfx("select")
	SaveManager.save_game()

func _open_settings() -> void:
	SoundBus.play_sfx("select")
	if _settings == null:
		_settings = SettingsMenuScript.new()
		_settings.name = "SettingsMenu"
		add_child(_settings)
		_settings.closed.connect(_on_settings_closed)
	_settings.visible = true
	_settings.focus_first()
	_settings_open = true
	_panel.visible = false

func _on_settings_closed() -> void:
	if _settings != null:
		_settings.visible = false
	_panel.visible = true
	_settings_open = false
	_resume_btn.grab_focus()

func _to_title() -> void:
	SoundBus.play_sfx("select")
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://ui/TitleScreen.tscn")
