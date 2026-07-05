# harvest_prompt.gd
# 收获提示UI - 当玩家靠近成熟作物时显示
# 挂载到 HarvestPrompt (Control) 根节点
extends Control

# ==================== 节点引用 ====================
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

# ==================== 状态 ====================
var target_pos: Vector2i = Vector2i(-1, -1)
var tilemap_layer: TileMapLayer
var player: Player
var farm_manager: FarmManager

var detection_range: int = 1          # 检测范围（玩家周围格数）
var is_harvesting: bool = false       # 防止重复收获

# ==================== 生命周期 ====================
func _ready():
	visible = false
	call_deferred("_setup_references")

# 获取场景引用（延迟执行）
func _setup_references():
	var root = get_tree().current_scene
	
	# 获取 Player
	player = root.find_child("Player", true, false) as Player
	if not player:
		push_error("HarvestPrompt: 找不到 Player！")
		return
	
	# 获取 TileMapLayer
	tilemap_layer = root.find_child("Field", true, false) as TileMapLayer
	if not tilemap_layer:
		tilemap_layer = root.find_child("Grass", true, false) as TileMapLayer
	if not tilemap_layer:
		for child in root.get_children():
			if child is TileMapLayer:
				tilemap_layer = child
				break
	
	if not tilemap_layer:
		push_error("HarvestPrompt: 找不到 TileMapLayer！")
		return
	
	# 获取 FarmManager（自动加载）
	farm_manager = FarmManager
	if not farm_manager:
		push_error("HarvestPrompt: 找不到 FarmManager！")
		return

# ==================== 主循环 ====================
func _process(_delta):
	# 安全检查
	if not tilemap_layer or not player or not farm_manager:
		return
	
	# 获取玩家所在格子
	var player_grid = tilemap_layer.local_to_map(player.global_position)
	
	# 查找周围是否有成熟作物
	var found_pos = _find_mature_crop(player_grid)
	
	if found_pos != Vector2i(-1, -1):
		target_pos = found_pos
		
		# 显示UI
		if not visible:
			visible = true
		
		# 将UI定位到作物上方
		var world_pos = tilemap_layer.map_to_local(target_pos)
		global_position = world_pos + Vector2(0, -60)
		
		# 检测空格键收获
		if Input.is_action_just_pressed("ui_accept"):
			_harvest_crop()
	else:
		# 没有成熟作物，隐藏UI
		if visible:
			visible = false
		target_pos = Vector2i(-1, -1)

# ==================== 检测方法 ====================
# 在玩家周围查找成熟作物
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
	
	# 执行收获
	var harvest_item = farm_manager.harvest_crop(target_pos)
	
	if harvest_item:
		# 添加到背包
		var added = player.player_inventory.add_item(harvest_item, 1)
		if added:
			# 收获成功，隐藏UI
			visible = false
			target_pos = Vector2i(-1, -1)
		# 如果背包已满，保留作物并提示
	else:
		# 收获失败（作物可能已被移除），隐藏UI
		visible = false
		target_pos = Vector2i(-1, -1)
	
	is_harvesting = false
