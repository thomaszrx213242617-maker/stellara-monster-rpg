extends Area3D
class_name EncounterZone

## 草丛遭遇区: 玩家进入时按概率触发野生灵兽战斗。
## pool 为可遭遇灵兽 id 列表; lvl_min/lvl_max 为等级区间。

signal triggered(creature_id: String, level: int)

var pool: Array = ["flarefox"]
var lvl_min: int = 2
var lvl_max: int = 6

func _ready() -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(8, 0.3, 8)
	m.mesh = bm
	m.position = Vector3(0, 0.15, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 0.25)
	m.material_override = mat
	add_child(m)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(8, 1.5, 8)
	col.shape = sh
	col.position = Vector3(0, 0.5, 0)
	add_child(col)

	body_entered.connect(_on_body_entered)

func _on_body_entered(b: Node) -> void:
	if b is PlayerController:
		var id: String = pool[randi() % pool.size()]
		var lv: int = randi_range(lvl_min, lvl_max)
		triggered.emit(id, lv)
