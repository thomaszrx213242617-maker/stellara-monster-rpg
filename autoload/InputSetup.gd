extends Node
class_name InputSetup

## 启动时用代码注册输入动作, 避免手工编辑 project.godot 的 [input] 格式。
## 这样即使未在编辑器里配过按键, 游戏也能直接跑。

func _ready() -> void:
    _ensure("move_forward", [KEY_W, KEY_UP])
    _ensure("move_back", [KEY_S, KEY_DOWN])
    _ensure("move_left", [KEY_A, KEY_LEFT])
    _ensure("move_right", [KEY_D, KEY_RIGHT])
    _ensure("dodge", [KEY_SHIFT])
    _ensure("attack", [KEY_SPACE])
    _ensure("interact", [KEY_E])
    _ensure("start_battle", [KEY_B])
    _ensure("capture", [KEY_C])

func _ensure(action_name: String, keys: Array) -> void:
    if InputMap.has_action(action_name):
        return
    InputMap.add_action(action_name)
    for k in keys:
        var ev := InputEventKey.new()
        ev.keycode = k
        InputMap.action_add_event(action_name, ev)
