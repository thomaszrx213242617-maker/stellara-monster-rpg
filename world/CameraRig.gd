extends Node3D
class_name CameraRig

## 第三人称跟随相机(原创, 不依赖外部插件)。
## 默认位于角色身后上方并始终看向角色; 右键拖动旋转视角(yaw/pitch)。
## 显式管理 Camera3D: 设为 current, 每帧平滑插值到期望机位并 look_at 角色,
## 避免 SpringArm3D 自动放置/朝向上的歧义, 确保「主控视角」一定是第三人称。

@export var follow_target: NodePath
@export var height: float = 3.2        ## 机位相对角色脚下的抬升高度
@export var distance: float = 9.0      ## 机位后退距离(角色背后多远)
@export var look_height: float = 1.4   ## 注视点相对角色脚下的高度(看向胸口/头部)
@export var follow_lerp: float = 9.0   ## 平滑跟随速度(越大越跟手)
@export var min_pitch: float = deg_to_rad(-72)
@export var max_pitch: float = deg_to_rad(35)
@export var base_fov: float = 75.0     ## 静止/慢走 FOV
@export var fast_fov: float = 84.0     ## 全速奔跑 FOV(轻微推近, 强化速度感)
@export var fov_speed_ref: float = 8.0 ## 达到此速度时 FOV 拉到 fast_fov
@export var bob_amp: float = 0.07      ## head bob 振幅(米)
@export var bob_freq: float = 10.0     ## head bob 频率(Hz)

var _cam: Camera3D
var _yaw: float = 0.0                  ## 初始 0: 相机在角色正背后(+Z), 角色面朝 -Z(屏幕里向前)
var _pitch: float = deg_to_rad(-16)
var _bob_t: float = 0.0                ## head bob 相位累加器

func _ready() -> void:
	_cam = Camera3D.new()
	_cam.current = true                 ## 显式设为当前相机, 确保第三人称视角生效
	_cam.near = 0.1
	_cam.far = 400.0
	add_child(_cam)

func _physics_process(delta: float) -> void:
	var target: Node3D = get_node_or_null(follow_target)
	if target == null:
		return
	var tp: Vector3 = target.global_position + Vector3(0, look_height, 0)
	# 期望机位: 以角色为原点, 先按 pitch 俯仰、再按 yaw 绕 Y 旋转的后退偏移
	var offset := Vector3(0, 0, distance)
	offset = offset.rotated(Vector3.RIGHT, _pitch)
	offset = offset.rotated(Vector3.UP, _yaw)
	var desired: Vector3 = tp + offset + Vector3(0, height, 0)
	desired.y = max(desired.y, 0.6)     ## 避免穿地
	var t: float = clamp(follow_lerp * delta, 0.0, 1.0)
	_cam.global_position = _cam.global_position.lerp(desired, t)
	# 速度感知: CharacterBody3D 才有 velocity, 其它目标保持 base_fov
	var spd: float = 0.0
	var on_floor: bool = false
	if target is CharacterBody3D:
		var cb: CharacterBody3D = target as CharacterBody3D
		spd = cb.velocity.length()
		on_floor = cb.is_on_floor()
	# 速度关联 FOV: 慢走接近 base, 奔跑接近 fast_fov(强化速度感)
	_cam.fov = lerpf(base_fov, fast_fov, clamp(spd / max(fov_speed_ref, 0.01), 0.0, 1.0))
	# Head bob: 仅在地面 + 实际移动时叠加微小正弦上下(让走路有"脚步感")
	var bob: float = 0.0
	if on_floor and spd > 0.5:
		_bob_t += delta * bob_freq
		bob = sin(_bob_t) * bob_amp
	else:
		_bob_t = 0.0
	_cam.look_at(tp + Vector3(0, bob, 0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.005
		_pitch = clamp(_pitch - event.relative.y * 0.005, min_pitch, max_pitch)
