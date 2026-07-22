extends SpringArm3D
class_name CameraRig

## 第三人称跟随相机 (不依赖外部插件, 用内置 SpringArm3D)。
## 右键拖动旋转视角。

@export var follow_target: NodePath
@export var height: float = 3.0
@export var distance: float = 9.0

func _ready() -> void:
	if get_child_count() == 0:
		var cam := Camera3D.new()
		add_child(cam)
	spring_length = distance
	rotation.x = deg_to_rad(-25)

func _physics_process(_delta: float) -> void:
	var target := get_node_or_null(follow_target)
	if target:
		global_position = target.global_position + Vector3(0, height, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotation.y -= event.relative.x * 0.005
		rotation.x = clamp(rotation.x - event.relative.y * 0.005, deg_to_rad(-70), deg_to_rad(5))
