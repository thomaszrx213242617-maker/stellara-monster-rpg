extends Area3D
class_name GymZone

## 道馆区域: 玩家进入后 World 监听 body_entered/body_exited 管理 _in_gym,
## 在区域内按 E 触发道馆战(训练家模式, 胜利获得徽章)。

func _ready() -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(8, 5, 8)
	m.mesh = bm
	m.position = Vector3(0, 2.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.62)
	m.material_override = mat
	add_child(m)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(8, 5, 8)
	col.shape = sh
	col.position = Vector3(0, 2.5, 0)
	add_child(col)

	# 蓝色屋顶标识
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.1
	rm.bottom_radius = 6.0
	rm.height = 2.0
	roof.mesh = rm
	roof.position = Vector3(0, 5.5, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.3, 0.5, 0.95)
	roof.material_override = rmat
	add_child(roof)
