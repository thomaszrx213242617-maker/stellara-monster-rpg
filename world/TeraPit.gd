extends Area3D
class_name TeraPit

## 原创「晶变坑」(对应宝可梦太晶坑机制, 规避版权): 一团水晶裂隙坑。
## 玩家靠近后由 World 监听 body_entered/exit, 在坑内按 E 触发三人协力讨伐。

func _ready() -> void:
	# 地面晶坑(暗色发光圆盘, 营造凹陷感)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 3.2
	dm.bottom_radius = 3.2
	dm.height = 0.4
	disc.mesh = dm
	disc.position = Vector3(0, 0.2, 0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.18, 0.22, 0.4)
	dmat.emission = Color(0.3, 0.5, 0.95)
	dmat.emission_energy = 0.5
	disc.material_override = dmat
	add_child(disc)
	# 晶簇(多根锥体, 金属质感)
	for i in range(7):
		var ang := float(i) / 7.0 * TAU
		var r := 2.2 + randf() * 0.6
		var h := 1.6 + randf() * 1.4
		var cr := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.4
		cm.height = h
		cr.mesh = cm
		cr.position = Vector3(cos(ang) * r, 0.2 + h / 2.0, sin(ang) * r)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.5, 0.7, 1.0)
		cmat.emission = Color(0.4, 0.6, 1.0)
		cmat.emission_energy = 0.7
		cmat.metallic = 0.35
		cmat.roughness = 0.15
		cr.material_override = cmat
		add_child(cr)
	# 碰撞(进入检测)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(7, 4, 7)
	col.shape = sh
	col.position = Vector3(0, 2, 0)
	add_child(col)
