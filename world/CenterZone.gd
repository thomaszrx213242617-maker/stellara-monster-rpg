extends Area3D
class_name CenterZone

## 宝可梦中心区域: 玩家进入后 World 监听 body_entered/body_exited 管理 _in_center,
## 在区域内按 E 触发治疗 + 自动存档(见 World.gd)。

func _ready() -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6, 4, 6)
	m.mesh = bm
	m.position = Vector3(0, 2, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.6, 0.7)
	m.material_override = mat
	add_child(m)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(6, 4, 6)
	col.shape = sh
	col.position = Vector3(0, 2, 0)
	add_child(col)

	# 屋顶标识
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.1
	rm.bottom_radius = 4.5
	rm.height = 1.5
	roof.mesh = rm
	roof.position = Vector3(0, 4.5, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.9, 0.3, 0.3)
	roof.material_override = rmat
	add_child(roof)
