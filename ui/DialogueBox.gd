extends Control
class_name DialogueBox

## 轻量对话 UI: 底部面板逐句显示台词, 按 E/空格 推进, 结束自动隐藏。
## 用于 NPC 与中心提示, 避免依赖外部插件即可跑通对话需求(T011)。

var lines: Array = []
var idx: int = 0
var active: bool = false
var _label: Label
## 打字机状态
var _full_text: String = ""
var _shown: int = 0
var _typing: bool = false
var _char_acc: float = 0.0

## 文字速度 → 每字间隔秒(0=瞬间显示); 对应 Game.text_speed 0/1/2
const _SPEED_DELAY := [0.05, 0.022, 0.0]

func _ready() -> void:
	visible = false
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.size = Vector2(668, 116)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	position = Vector2(40, 420)
	size = Vector2(700, 140)

func start(d: Array) -> void:
	if d.is_empty():
		return
	lines = d
	idx = 0
	active = true
	visible = true
	_show()

func _show() -> void:
	if idx >= lines.size():
		_end()
		return
	_full_text = str(lines[idx])
	_shown = 0
	_typing = true
	_char_acc = 0.0
	_label.text = ""

func _process(delta: float) -> void:
	if not active:
		return
	if _typing:
		var spd := Game.text_speed
		if spd < 0 or spd > 2:
			spd = 1
		var delay: float = _SPEED_DELAY[spd]
		if delay <= 0.0:
			_label.text = _full_text
			_typing = false
		else:
			_char_acc += delta
			while _typing and _char_acc >= delay and _shown < _full_text.length():
				_char_acc -= delay
				_shown += 1
				_label.text = _full_text.substr(0, _shown)
			if _shown >= _full_text.length():
				_typing = false
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		if _typing:
			# 正在打字: 立即补全本句(不推进)
			_typing = false
			_label.text = _full_text
		else:
			idx += 1
			SFX.play_sfx("select")
			_show()

func _end() -> void:
	active = false
	_typing = false
	visible = false
