extends Control
class_name DialogueBox

## 轻量对话 UI: 底部面板逐句显示台词, 按 E/空格 推进, 结束自动隐藏。
## 用于 NPC 与中心提示, 避免依赖外部插件即可跑通对话需求(T011)。

var lines: Array = []
var idx: int = 0
var active: bool = false
var _label: Label

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
	_label.text = str(lines[idx])

func _process(_delta: float) -> void:
	if not active:
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		idx += 1
		SoundBus.play_sfx("select")
		_show()

func _end() -> void:
	active = false
	visible = false
