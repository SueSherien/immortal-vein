# harvest_prompt.gd
# 收获提示UI - 当玩家靠近成熟作物时显示
# 适配：War3TileMapLayer（4 子层包装节点）
extends Control

# ==================== 节点引用 ====================
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

# ==================== 状态 ====================
var target_pos: Vector2i = Vector2i(-1, -1)
# 坐标参考子层（来自 FarmManager）
var reference_layer: TileMapLayer = null
var player: Player = null
var farm_manager: FarmManager = null

var detection_range: int = 1
var is_harvesting: bool = false

# ==================== 生命周期 ====================
func _ready():
	visible = false
	call_deferred("_deferred_setup")

func _deferred_setup():
	await get_tree().process_frame
	_setup_references()

func _setup_references():
	var root = get_tree().current_scene
	if not root:
		root = get_tree().root

	# --- 获取 FarmManager（自动加载）---
	farm_manager = FarmManager
	if not farm_manager:
		push_error("HarvestPrompt: 找不到 FarmManager！")
		return

	# 等 FarmManager 完成初始化
	if farm_manager.reference_layer == null:
		# 再等一帧
		await get_tree().process_frame
	if farm_manager.reference_layer == null:
		push_error("HarvestPrompt: FarmManager 未完成初始化（reference_layer 为空）")
		return

	reference_layer = farm_manager.reference_layer

	# --- 获取 Player ---
	player = _find_player(root)
	if not player:
		push_error("HarvestPrompt: 找不到 Player！")
		return

# 递归查找 Player（利用 class_name）
func _find_player(node: Node) -> Player:
	for child in node.get_children():
		if child is Player:
			return child
		var found = _find_player(child)
		if found:
			return found
	return null

# ==================== 主循环 ====================
func _process(_delta):
	if not reference_layer or not player or not farm_manager:
		return

	var player_grid = reference_layer.local_to_map(player.global_position)
	var found_pos = _find_mature_crop(player_grid)

	if found_pos != Vector2i(-1, -1):
		target_pos = found_pos
		if not visible:
			visible = true

		var world_pos = reference_layer.map_to_local(target_pos)
		global_position = world_pos + Vector2(0, -60)

		if Input.is_action_just_pressed("ui_accept"):
			_harvest_crop()
	else:
		if visible:
			visible = false
		target_pos = Vector2i(-1, -1)

# ==================== 检测方法 ====================
func _find_mature_crop(player_grid: Vector2i) -> Vector2i:
	for dx in range(-detection_range, detection_range + 1):
		for dy in range(-detection_range, detection_range + 1):
			var pos = player_grid + Vector2i(dx, dy)
			if farm_manager.is_crop_mature(pos):
				return pos
	return Vector2i(-1, -1)

# ==================== 收获方法 ====================
func _harvest_crop():
	if is_harvesting or target_pos == Vector2i(-1, -1):
		return

	is_harvesting = true

	var harvest_item = farm_manager.harvest_crop(target_pos)

	if harvest_item:
		var added = player.player_inventory.add_item(harvest_item, 1)
		if added:
			visible = false
			target_pos = Vector2i(-1, -1)
	else:
		visible = false
		target_pos = Vector2i(-1, -1)

	is_harvesting = false
