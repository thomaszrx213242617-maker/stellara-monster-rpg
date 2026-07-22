extends CharacterBody3D
class_name Npc

## 场景中的 NPC: 玩家靠近并按 E 时, 通过 dialogue_box 播放台词。

var lines: Array = []
var player_ref = null
var dialogue_box: Node = null

func _ready() -> void:
	var m := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 1.6
	m.mesh = cap
	m.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.3)
	m.material_override = mat
	add_child(m)
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius = 0.5
	shp.height = 1.6
	col.shape = shp
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

func _physics_process(_delta: float) -> void:
	if player_ref == null or dialogue_box == null:
		return
	if global_position.distance_to(player_ref.global_position) < 4.0:
		if Input.is_action_just_pressed("interact"):
			if dialogue_box.has_method("start"):
				dialogue_box.start(lines)
