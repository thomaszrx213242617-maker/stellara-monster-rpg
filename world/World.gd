extends Node3D
class_name World

## 探索场景: 在 _ready 中代码构建世界(环境/光照/地面/玩家/相机/UI)。
## 按 B 进入实时战斗原型。MVP 切片: 扁平测试场地 + 可行走玩家。

const PlayerScript := preload("res://world/PlayerController.gd")
const CameraScript := preload("res://world/CameraRig.gd")

var _player
var _camera
var _env: Environment
var _light: DirectionalLight3D
var _time_label: Label

func _ready() -> void:
    build_world()
    _build_ui()
    DayNight.time_changed.connect(_on_time)
    _on_time(0.0)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var hint := Label.new()
    hint.text = "WASD 移动 | 鼠标右键拖动转视角 | 空格跳跃 | 按 B 进入实时战斗 | 夜晚按 C 收服会被拒绝"
    hint.position = Vector2(12, 12)
    layer.add_child(hint)
    var t := Label.new()
    t.name = "TimeLabel"
    t.position = Vector2(12, 36)
    layer.add_child(t)
    _time_label = t

func _on_time(_t: float) -> void:
    if _time_label:
        _time_label.text = "时间: " + DayNight.phase_label()

func build_world() -> void:
    var env_node := WorldEnvironment.new()
    add_child(env_node)
    _env = Environment.new()
    _env.background_mode = Environment.BG_COLOR
    _env.background_color = Color(0.6, 0.75, 0.95)
    _env.ambient_light_energy = 0.6
    env_node.environment = _env

    _light = DirectionalLight3D.new()
    _light.position = Vector3(10, 25, 10)
    _light.rotation = Vector3(deg_to_rad(-55), 0, 0)
    _light.light_energy = 1.2
    add_child(_light)

    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(80, 80)
    ground.mesh = plane
    ground.rotate_x(deg_to_rad(-90))
    add_child(ground)

    var sb := StaticBody3D.new()
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(80, 0.2, 80)
    col.shape = shape
    col.position = Vector3(0, -0.1, 0)
    sb.add_child(col)
    add_child(sb)

    # 一些占位障碍物 (程序生成)
    for i in range(8):
        var b := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(2, randf_range(1, 3), 2)
        b.mesh = bm
        b.position = Vector3(randf_range(-25, 25), bm.size.y / 2.0, randf_range(-25, 25))
        add_child(b)

    _player = PlayerScript.new()
    _player.position = Vector3(0, 1, 0)
    add_child(_player)

    _camera = CameraScript.new()
    add_child(_camera)
    _camera.follow_target = _camera.get_path_to(_player)

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("start_battle"):
        get_tree().change_scene_to_file("res://battle/BattleArena.tscn")
    # 昼夜光照反馈
    if _env:
        if DayNight.is_night:
            _env.background_color = Color(0.05, 0.05, 0.12)
            if _light:
                _light.light_energy = 0.3
        else:
            _env.background_color = Color(0.6, 0.75, 0.95)
            if _light:
                _light.light_energy = 1.2
