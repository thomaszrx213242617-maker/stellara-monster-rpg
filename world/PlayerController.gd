extends CharacterBody3D
class_name PlayerController

## 朱紫式 3D 玩家控制器: WASD 相机相对移动、跳跃、朝向。

@export var speed: float = 7.0
@export var jump_velocity: float = 7.0
var gravity: float = 22.0

func _ready() -> void:
	# 占位玩家模型 (蓝色胶囊)
	var m := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 1.6
	m.mesh = cap
	m.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 1.0)
	m.material_override = mat
	add_child(m)
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius = 0.5
	shp.height = 1.6
	col.shape = shp
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("attack"):
			velocity.y = jump_velocity
		else:
			velocity.y = 0.0

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.z -= 1
	if Input.is_action_pressed("move_back"): input_dir.z += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1

	var dir := Vector3.ZERO
	if input_dir != Vector3.ZERO:
		var cam := get_viewport().get_camera_3d()
		var basis := Basis()
		if cam:
			basis = cam.global_transform.basis
		var fwd := -basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var right := basis.x
		right.y = 0
		right = right.normalized()
		dir = (fwd * -input_dir.z + right * input_dir.x).normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP)
	move_and_slide()
