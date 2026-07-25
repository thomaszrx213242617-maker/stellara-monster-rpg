extends CharacterBody3D
class_name Npc

## 场景中的 NPC: 玩家靠近并按 E 时, 通过 dialogue_box 播放台词。
## Q版外观(大头小身) + 头顶名字标签; 颜色与名字可由 World 配置。

var lines: Array = []
var player_ref = null
var dialogue_box: Node = null
var npc_color: Color = Color(0.9, 0.8, 0.3)
var display_name: String = "居民"

func _ready() -> void:
	# Q版身体(小)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.32
	bm.height = 0.7
	body.mesh = bm
	body.position = Vector3(0, 0.55, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = npc_color
	bmat.roughness = 0.6
	bmat.metallic = 0.05
	body.material_override = bmat
	add_child(body)
	# Q版头(大)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.42
	hm.height = 0.6
	head.mesh = hm
	head.position = Vector3(0, 1.15, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.98, 0.85, 0.72)
	hmat.roughness = 0.55
	head.material_override = hmat
	add_child(head)
	# 眼睛(朝向 +Z, 更生动)
	for sx in [-0.15, 0.15]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.07
		em.height = 0.14
		eye.mesh = em
		eye.position = Vector3(sx, 1.2, 0.36)
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.12, 0.12, 0.16)
		eye.material_override = emat
		add_child(eye)
	# 碰撞
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius = 0.5
	shp.height = 1.6
	col.shape = shp
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	# 头顶名字标签
	if display_name != "":
		var tag := Label3D.new()
		tag.text = display_name
		tag.position = Vector3(0, 1.95, 0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 32
		add_child(tag)

func _physics_process(_delta: float) -> void:
	if player_ref == null or dialogue_box == null:
		return
	if global_position.distance_to(player_ref.global_position) < 4.0:
		if Input.is_action_just_pressed("interact"):
			if dialogue_box.has_method("start"):
				dialogue_box.start(lines)
