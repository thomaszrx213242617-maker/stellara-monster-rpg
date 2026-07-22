extends CharacterBody3D
class_name Combatant

## 战斗中的一只灵兽: 承载属性/血量与移动。玩家与敌方共用, 由 is_player 区分。
## 移动方向由外部(玩家输入 / 敌方 AI)写入 move_dir, 本脚本负责物理与受击表现。

signal hp_changed(current: int, maximum: int)
signal defeated_signal

var creature_id: String = "flarefox"
var level: int = 5
var type: String = "炎"
var max_hp: int = 100
var hp: int = 100
var stats: Dictionary = {}
var moves: Array = []
var is_player: bool = false
var defeated: bool = false

var move_dir: Vector3 = Vector3.ZERO
@export var move_speed: float = 5.0
var invulnerable: float = 0.0
var gravity: float = 22.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
    var m := MeshInstance3D.new()
    m.name = "MeshInstance3D"
    var cap := CapsuleMesh.new()
    cap.radius = 0.6
    cap.height = 1.6
    m.mesh = cap
    m.position = Vector3(0, 0.9, 0)
    add_child(m)
    mesh = m
    var col := CollisionShape3D.new()
    var shp := CapsuleShape3D.new()
    shp.radius = 0.6
    shp.height = 1.6
    col.shape = shp
    col.position = Vector3(0, 0.9, 0)
    add_child(col)

func setup(creature_id_: String, level_: int, is_player_: bool) -> void:
    creature_id = creature_id_
    level = level_
    is_player = is_player_
    var data: Dictionary = DataBus.get_creature(creature_id)
    if data.is_empty():
        return
    type = data.get("type", "炎")
    stats = DataBus.compute_stats(data, level)
    max_hp = stats["max_hp"]
    hp = max_hp
    moves = data.get("moves", [])
    _apply_color()
    hp_changed.emit(hp, max_hp)

func _apply_color() -> void:
    var colors := {
        "炎": Color(0.9, 0.3, 0.2), "水": Color(0.2, 0.4, 0.9), "木": Color(0.3, 0.7, 0.3),
        "雷": Color(0.9, 0.9, 0.2), "岩": Color(0.6, 0.5, 0.4), "风": Color(0.7, 0.9, 0.8),
        "光": Color(1.0, 0.95, 0.6), "暗": Color(0.3, 0.2, 0.4), "械": Color(0.7, 0.7, 0.75),
        "灵": Color(0.8, 0.6, 0.9)
    }
    var c: Color = colors.get(type, Color(0.8, 0.8, 0.8))
    if mesh:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = c
        mesh.material_override = mat

func _physics_process(delta: float) -> void:
    invulnerable = max(0.0, invulnerable - delta)
    if defeated:
        velocity = Vector3.ZERO
        move_and_slide()
        return
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0
    velocity.x = move_dir.x * move_speed
    velocity.z = move_dir.z * move_speed
    if move_dir.length() > 0.01:
        look_at(global_position + Vector3(move_dir.x, 0, move_dir.z), Vector3.UP)
    move_and_slide()

func take_damage(amount: float) -> void:
    if defeated:
        return
    hp -= int(amount)
    if hp <= 0:
        hp = 0
        defeated = true
        defeated_signal.emit()
    hp_changed.emit(hp, max_hp)
    # 受击缩放反馈
    if mesh:
        var t := create_tween()
        t.tween_property(mesh, "scale", Vector3(1.15, 1.15, 1.15), 0.05)
        t.tween_property(mesh, "scale", Vector3.ONE, 0.1)
