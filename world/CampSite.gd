extends Area3D
class_name CampSite

## 路旁帐篷营地: 玩家进入区域内按 E 可「扎营睡觉」——回满队伍与自身体力并自动存档,
## 同时把此处记为最近存档点(野外被击败时复活到这里)。World 负责监听 entered/exited 与 E 交互。

func _ready() -> void:
	# 帐篷(圆锥)
	var tent := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 1.6
	cm.height = 2.2
	tent.mesh = cm
	tent.position = Vector3(0, 1.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.55, 0.35)
	tent.material_override = mat
	add_child(tent)
	# 帐篷门
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.9, 1.2, 0.1)
	door.mesh = dm
	door.position = Vector3(0, 0.6, 1.55)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.3, 0.2, 0.15)
	door.material_override = dmat
	add_child(door)
	# 营火(橙色小球)
	var fire := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.25
	fm.height = 0.4
	fire.mesh = fm
	fire.position = Vector3(2.2, 0.3, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.55, 0.2)
	fire.material_override = fmat
	add_child(fire)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(6, 4, 6)
	col.shape = sh
	col.position = Vector3(0, 2, 0)
	add_child(col)

	var tag := Label3D.new()
	tag.text = "营地 · 按 E 扎营休息"
	tag.position = Vector3(0, 3.0, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 24
	add_child(tag)
