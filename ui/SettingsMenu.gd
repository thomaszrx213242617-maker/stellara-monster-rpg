extends Control

## 通用设置菜单(覆盖层)。标题画面与暂停菜单共用。
## 提供: 音乐 开/关 + 音量滑条, 音效 开/关 + 音量滑条, 文字速度(慢/中/快), 全屏 开/关, 返回。
## 改动即时生效并自动存档(Game + Save); 暴露 closed 信号供调用方收回焦点。
## 不自行处理 Esc: 由调用方在 _unhandled_input 中优先关闭本菜单(避免与暂停菜单的 Esc 冲突)。

signal closed

var _b_music: Button
var _b_sfx: Button
var _b_speed: Button
var _b_full: Button
var _b_musicfile: Button
var _s_music: HSlider
var _s_sfx: HSlider
var _v_music: Label
var _v_sfx: Label
var _first: Button
var _music_options: Array = []
var _music_idx: int = 0

const _SPEED_LABEL := ["慢", "中", "快"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(420, 0)
	add_child(vb)

	var t := Label.new()
	t.text = "设置"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 38)
	t.modulate = Color(0.95, 0.97, 1.0)
	vb.add_child(t)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	vb.add_child(sp)

	# 音乐 开/关
	_b_music = _btn("音乐: " + ("开" if Game.music_on else "关"))
	_b_music.pressed.connect(_toggle_music)
	vb.add_child(_b_music)
	_first = _b_music

	# 音乐音量
	var hm := HBoxContainer.new()
	hm.alignment = BoxContainer.ALIGNMENT_CENTER
	var lm := Label.new(); lm.text = "音乐音量"; lm.add_theme_font_size_override("font_size", 18); lm.modulate = Color(0.85, 0.88, 0.95)
	_s_music = HSlider.new(); _s_music.min_value = 0; _s_music.max_value = 100; _s_music.step = 1
	_s_music.custom_minimum_size = Vector2(220, 24)
	_s_music.value = int(Game.music_volume * 100)
	_v_music = Label.new(); _v_music.text = _pct(Game.music_volume); _v_music.custom_minimum_size = Vector2(48, 0); _v_music.add_theme_font_size_override("font_size", 16)
	hm.add_child(lm); hm.add_child(_s_music); hm.add_child(_v_music)
	vb.add_child(hm)
	_s_music.value_changed.connect(_on_music_vol)

	# 背景音乐文件(自定义 BGM): 在「原创合成」与用户放入 res://audio/ 的文件间循环
	var opts: Array = [{"name": "原创合成", "path": ""}]
	for m in BGM.list_music_files():
		opts.append(m)
	_music_options = opts
	_music_idx = 0
	for i in opts.size():
		if opts[i]["path"] == Game.custom_music:
			_music_idx = i
			break
	_b_musicfile = _btn("背景音乐: " + opts[_music_idx]["name"])
	_b_musicfile.pressed.connect(_cycle_music_file)
	vb.add_child(_b_musicfile)

	# 音效 开/关
	_b_sfx = _btn("音效: " + ("开" if Game.sfx_on else "关"))
	_b_sfx.pressed.connect(_toggle_sfx)
	vb.add_child(_b_sfx)

	# 音效音量
	var hs := HBoxContainer.new()
	hs.alignment = BoxContainer.ALIGNMENT_CENTER
	var ls := Label.new(); ls.text = "音效音量"; ls.add_theme_font_size_override("font_size", 18); ls.modulate = Color(0.85, 0.88, 0.95)
	_s_sfx = HSlider.new(); _s_sfx.min_value = 0; _s_sfx.max_value = 100; _s_sfx.step = 1
	_s_sfx.custom_minimum_size = Vector2(220, 24)
	_s_sfx.value = int(Game.sfx_volume * 100)
	_v_sfx = Label.new(); _v_sfx.text = _pct(Game.sfx_volume); _v_sfx.custom_minimum_size = Vector2(48, 0); _v_sfx.add_theme_font_size_override("font_size", 16)
	hs.add_child(ls); hs.add_child(_s_sfx); hs.add_child(_v_sfx)
	vb.add_child(hs)
	_s_sfx.value_changed.connect(_on_sfx_vol)

	# 文字速度
	_b_speed = _btn("文字速度: " + _SPEED_LABEL[_clamp_speed()])
	_b_speed.pressed.connect(_cycle_speed)
	vb.add_child(_b_speed)

	# 全屏
	_b_full = _btn("全屏: " + ("开" if _is_fullscreen() else "关"))
	_b_full.pressed.connect(_toggle_fullscreen)
	vb.add_child(_b_full)

	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 10)
	vb.add_child(sp2)

	var b_back := _btn("返回")
	b_back.pressed.connect(close)
	vb.add_child(b_back)

func _btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 48)
	b.add_theme_font_size_override("font_size", 20)
	return b

func _pct(v: float) -> String:
	return str(int(clamp(v, 0.0, 1.0) * 100)) + "%"

func _clamp_speed() -> int:
	return clamp(Game.text_speed, 0, 2)

func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

## 由调用方在打开时调用: 聚焦首项
func focus_first() -> void:
	if _first != null:
		_first.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func _toggle_music() -> void:
	var on := not Game.music_on
	BGM.set_music_enabled(on)
	_b_music.text = "音乐: " + ("开" if on else "关")
	Save.save_game()
	SFX.play_sfx("select")

## 循环切换背景音乐: 原创合成 ↔ 用户放入 res://audio/ 的音乐文件, 即时试听并保存。
func _cycle_music_file() -> void:
	if _music_options.is_empty():
		return
	_music_idx = (_music_idx + 1) % _music_options.size()
	var opt: Dictionary = _music_options[_music_idx]
	Game.custom_music = opt["path"]
	BGM.set_custom_music(opt["path"])
	_b_musicfile.text = "背景音乐: " + opt["name"]
	SFX.play_sfx("select")
	Save.save_game()

func _on_music_vol(v: float) -> void:
	BGM.set_music_volume(v / 100.0)
	_v_music.text = _pct(v / 100.0)
	Save.save_game()

func _toggle_sfx() -> void:
	var on := not Game.sfx_on
	SFX.set_sfx_enabled(on)
	_b_sfx.text = "音效: " + ("开" if on else "关")
	if on:
		SFX.play_sfx("select")
	Save.save_game()

func _on_sfx_vol(v: float) -> void:
	SFX.set_sfx_volume(v / 100.0)
	_v_sfx.text = _pct(v / 100.0)
	Save.save_game()

func _cycle_speed() -> void:
	Game.text_speed = (_clamp_speed() + 1) % 3
	_b_speed.text = "文字速度: " + _SPEED_LABEL[_clamp_speed()]
	SFX.play_sfx("select")
	Save.save_game()

func _toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_b_full.text = "全屏: " + ("开" if _is_fullscreen() else "关")
	SFX.play_sfx("select")
