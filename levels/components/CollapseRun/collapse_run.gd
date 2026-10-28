class_name CollapseRun
extends Node3D

## «Сбой»: после победы на арене из пустоты поднимается дорожка из хрупких
## камней (дочерние MovingPlatform в узле Stones), которые рушатся под ногами.

@export var arena: Node
@export var rise_depth: float = 12.0
@export var rise_time: float = 0.6
@export var rise_interval: float = 0.15
@export var rumble_strength: float = 0.6
@export var rumble_duration: float = 1.5

@onready var stones_root: Node3D = $Stones

var _stones: Array[Node3D] = []
var _rest_positions: Array[Vector3] = []


func _ready() -> void:
	for child in stones_root.get_children():
		if child is Node3D:
			_stones.append(child)
			_rest_positions.append(child.position)

	var already_cleared: bool = arena != null and arena.get("is_cleared") == true
	if already_cleared:
		return
	for i in _stones.size():
		_set_stone_active(_stones[i], false)
		_stones[i].position = _rest_positions[i] + Vector3.DOWN * rise_depth
	if arena and arena.has_signal("cleared"):
		arena.cleared.connect(start)


func start() -> void:
	_rumble()
	for i in _stones.size():
		var stone := _stones[i]
		_set_stone_active(stone, true)
		var tween := create_tween()
		tween.tween_property(stone, "position", _rest_positions[i], rise_time)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(rise_interval).timeout
		if not is_inside_tree(): return


func _rumble() -> void:
	var elapsed := 0.0
	while elapsed < rumble_duration:
		get_tree().call_group("camera_shaker", "add_trauma", rumble_strength * 0.3)
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree(): return
		elapsed += 0.2


func _set_stone_active(stone: Node3D, value: bool) -> void:
	stone.visible = value
	stone.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
