# ============================================================================
# farm_manager.gd
# 全局农场管理器 - 管理所有作物的种植、生长、收获
# 依赖：TimeManager (自动加载), PlantData (资源), crop.tscn (场景)
# ============================================================================
extends Node

# ==================== 作物数据类 ====================
# 每个作物实例的运行数据，存储在 crop_map 中
class CropData:
	var position: Vector2i          # 所在格子坐标
	var plant_data: PlantData       # 作物数据资源（定义生长参数和贴图）
	var current_stage: int = 0      # 当前生长阶段 (0:发芽, 1:生长, 2:即将成熟, 3:成熟)
	var growth_progress: int = 0    # 已生长天数
	var is_mature: bool = false     # 是否已成熟（可收获）
	var is_withered: bool = false   # 是否枯萎（多年生过季，预留）
	var crop_node: Node2D           # 场景中的显示节点
	var harvest_count: int = 0      # 已收获次数（仅多年生使用）

# ==================== 信号 ====================
# 作物种植信号 - 参数：格子坐标
signal crop_planted(position: Vector2i)
# 作物收获信号 - 参数：格子坐标
signal crop_harvested(position: Vector2i)
# 作物枯萎信号 - 参数：格子坐标（预留）
signal crop_withered(position: Vector2i)

# ==================== 引用 ====================
# 所有作物字典，键为 Vector2i 格子坐标，值为 CropData
var crop_map: Dictionary = {}
# 地面瓦片地图层引用（由外部注入）
var tilemap_layer: TileMapLayer
# 作物显示节点容器（所有 Crop 实例的父节点）
var crops_container: Node2D

# 作物场景路径（在编辑器中配置）
const CROP_SCENE = "res://scenes/objects/plants/crop.tscn"

# ==================== 初始化 ====================
func _ready():
	# 连接时间管理器的"一天结束"信号
	if not TimeManager.day_ended.is_connected(_on_day_end):
		TimeManager.day_ended.connect(_on_day_end)
	
	# 延迟获取场景引用，确保其他节点已加载
	call_deferred("_setup_references")

# 获取场景引用
func _setup_references():
	var root = get_tree().current_scene

	# --- 获取 TileMapLayer ---
	# 优先查找 "Field" 层（耕地）
	tilemap_layer = root.find_child("Field", true, false) as TileMapLayer
	if not tilemap_layer:
		# 其次查找 "Grass" 层（草地）
		tilemap_layer = root.find_child("Grass", true, false) as TileMapLayer
	if not tilemap_layer:
		# 最后遍历查找任意 TileMapLayer
		for child in root.get_children():
			if child is TileMapLayer:
				tilemap_layer = child
				break

	if not tilemap_layer:
		push_error("farm_manager: 找不到 TileMapLayer！")
		return

	# --- 获取或创建作物容器 ---
	# 所有作物实例都放在这个容器下，便于统一管理
	crops_container = root.find_child("Crops", true, false)
	if not crops_container:
		# 如果不存在则动态创建
		crops_container = Node2D.new()
		crops_container.name = "Crops"
		root.add_child(crops_container)

# ==================== 地形检测 ====================
# 检查指定格子是否为可种植地形
# 需要 TileSet 中为瓦片设置自定义数据 "ground_type"
# 可种植类型: "field" 或 "wet_field"
func is_plantable(grid_pos: Vector2i) -> bool:
	if not tilemap_layer:
		return false

	# 获取该格子的瓦片数据
	var tile_data = tilemap_layer.get_cell_tile_data(grid_pos)
	if not tile_data:
		return false

	# 读取自定义数据 "ground_type"
	var ground_type = tile_data.get_custom_data("ground_type")
	# 判断是否为可种植地形
	return ground_type == "field" or ground_type == "wet_field"

# ==================== 距离检测 ====================
# 检查目标格子是否在玩家的交互范围内（视觉相邻的8个格子）
# 用于判断玩家是否能种植或收获作物
func is_within_range(player_grid: Vector2i, target_grid: Vector2i) -> bool:
	var dx = target_grid.x - player_grid.x
	var dy = target_grid.y - player_grid.y
	# 视觉上相邻的8个格子（含玩家自身）
	var is_adjacent = (
	(dx == -2 and dy == 0)  or  # 上
	(dx == -1 and dy == -1) or  # 左上
	(dx == -1 and dy == 1)  or  # 右上
	(dx == 0 and dy == -2)  or  # 左
	(dx == 0 and dy == 2)   or  # 右
	(dx == 1 and dy == -1)  or  # 左下
	(dx == 1 and dy == 1)   or  # 右下
	(dx == 2 and dy == 0)        # 下
	)
	
	return is_adjacent

# ==================== 种植 ====================
# 在指定格子种植作物
# 参数: grid_pos - 格子坐标, plant_data - 作物数据资源
# 返回: bool - 是否种植成功
func plant_crop(grid_pos: Vector2i, plant_data: PlantData) -> bool:
	# 检查该位置是否已被占用
	if crop_map.has(grid_pos):
		return false

	# 验证数据有效性
	if not plant_data or not tilemap_layer:
		return false

	# 验证 PlantData 是否包含阶段贴图
	if plant_data.growth_stage_textures.is_empty():
		push_error("plant_data: 阶段贴图为空！")
		return false

	# --- 创建作物运行数据 ---
	var crop = CropData.new()
	crop.position = grid_pos
	crop.plant_data = plant_data
	# 初始状态：阶段 0（发芽），未成熟

	# --- 创建显示节点 ---
	crop.crop_node = _create_crop_node(grid_pos, plant_data, 0)
	if not crop.crop_node:
		return false

	# --- 存入字典 ---
	crop_map[grid_pos] = crop
	crop_planted.emit(grid_pos)
	return true

# 创建作物显示节点
# 参数: grid_pos - 格子坐标, plant_data - 作物数据, stage - 初始阶段
# 返回: Node2D - 创建的作物场景实例
func _create_crop_node(grid_pos: Vector2i, plant_data: PlantData, stage: int) -> Node2D:
	# 加载作物场景
	var scene = load(CROP_SCENE)
	if not scene:
		push_error("farm_manager: 无法加载作物场景: %s" % CROP_SCENE)
		return null

	# 实例化场景
	var instance = scene.instantiate() as Node2D
	if not instance:
		push_error("farm_manager: 作物场景实例化失败")
		return null

	# 设置世界坐标（格子坐标 -> 世界坐标）
	instance.position = tilemap_layer.map_to_local(grid_pos)

	# 获取 Sprite 节点（用于显示贴图）
	var sprite = instance.get_node("Sprite") as Sprite2D
	if not sprite:
		# 兼容不同命名：遍历子节点查找 Sprite2D
		for child in instance.get_children():
			if child is Sprite2D:
				sprite = child
				break

	# ===== 应用 Y 轴偏移 =====
	# 不同作物因外观不同，需要不同的偏移值来对齐地图格
	# 偏移值在 PlantData 资源中配置，在此处应用到精灵节点
	if sprite and plant_data:
		# 将 PlantData 中的 y_offset 应用到精灵的局部位置
		# 正值向下移动，负值向上移动
		sprite.position.y = plant_data.y_offset
		
		# 设置初始贴图
		var tex = plant_data.get_stage_texture(stage)
		if tex:
			sprite.texture = tex
		else:
			push_warning("farm_manager: 作物阶段 %d 贴图为空" % stage)

	# 添加到作物容器
	if crops_container:
		crops_container.add_child(instance)
	else:
		get_tree().current_scene.add_child(instance)

	return instance

# ==================== 生长 ====================
# 每天结束时调用（由 TimeManager.day_ended 信号触发）
# 遍历所有作物，更新生长进度
func _on_day_end():
	for pos in crop_map.keys():
		var crop = crop_map[pos]

		# 跳过枯萎或已成熟的作物
		if crop.is_withered or crop.is_mature:
			continue

		# 生长进度 +1 天
		crop.growth_progress += 1

		# 检查是否达到成熟所需天数
		if crop.growth_progress >= crop.plant_data.growth_days:
			# 成熟：阶段设为 3，标记为已成熟
			crop.is_mature = true
			crop.current_stage = 3
			_update_display(pos)
		else:
			# 未成熟：更新生长阶段 (0~2)
			var new_stage = _calc_stage(crop)
			if new_stage != crop.current_stage:
				crop.current_stage = new_stage
				_update_display(pos)

# 计算当前生长阶段
# 根据生长进度与总天数的比例计算阶段
# 返回值: 0=发芽, 1=生长, 2=即将成熟
func _calc_stage(crop: CropData) -> int:
	var ratio = float(crop.growth_progress) / float(crop.plant_data.growth_days)
	if ratio >= 0.75:
		return 2
	elif ratio >= 0.4:
		return 1
	return 0

# 更新作物的显示贴图
# 根据当前状态（枯萎/成熟/生长阶段）选择对应的贴图
# 同时确保 Y 轴偏移始终被应用（防止被意外重置）
func _update_display(grid_pos: Vector2i):
	var crop = crop_map.get(grid_pos)
	if not crop or not crop.crop_node:
		return

	var sprite = crop.crop_node.get_node("Sprite") as Sprite2D
	if not sprite:
		return

	# ===== 确保偏移始终保持 =====
	# 在更新贴图时重新应用偏移，防止其他逻辑意外重置了精灵位置
	# 这是为了健壮性，确保偏移值在任何情况下都被正确应用
	if crop.plant_data:
		sprite.position.y = crop.plant_data.y_offset

	# 根据状态选择贴图
	var tex: Texture2D
	if crop.is_withered:
		# 枯萎：使用枯萎贴图
		tex = crop.plant_data.withered_texture
	elif crop.is_mature:
		# 成熟：使用阶段 3 贴图
		tex = crop.plant_data.get_stage_texture(3)
	else:
		# 生长中：根据当前阶段获取贴图
		tex = crop.plant_data.get_stage_texture(crop.current_stage)

	if tex:
		sprite.texture = tex
	else:
		# 如果贴图为空，记录警告
		push_warning("farm_manager: 作物 %s 贴图为空" % grid_pos)

# ==================== 收获 ====================
# 收获指定位置的作物
# 参数: grid_pos - 格子坐标
# 返回: ItemData - 收获的物品，失败返回 null
func harvest_crop(grid_pos: Vector2i) -> ItemData:
	var crop = crop_map.get(grid_pos)
	# 检查该位置是否有作物且已成熟
	if not crop or not crop.is_mature:
		return null

	# 获取收获物品
	var item = crop.plant_data.harvest_item
	if not item:
		push_warning("farm_manager: 作物 %s 没有设置收获物品" % grid_pos)
		return null

	# === 根据收获类型处理 ===
	if crop.plant_data.harvest_type == 0:
		# 一年生：收获后作物消失
		_remove_crop(grid_pos)
	else:
		# 多年生：收获后重置生长，等待再次成熟
		crop.is_mature = false
		crop.growth_progress = 1
		crop.current_stage = 1
		crop.harvest_count += 1
		_update_display(grid_pos)

	crop_harvested.emit(grid_pos)
	return item

# 移除作物（完全删除）
func _remove_crop(grid_pos: Vector2i):
	var crop = crop_map.get(grid_pos)
	if crop:
		# 从场景中移除显示节点
		if crop.crop_node:
			crop.crop_node.queue_free()
		# 从字典中移除数据
		crop_map.erase(grid_pos)

# ==================== 铲除枯萎 ====================
# 铲除枯萎的作物（需要使用工具）
# 参数: grid_pos - 格子坐标
# 返回: bool - 是否成功铲除
func remove_withered(grid_pos: Vector2i) -> bool:
	var crop = crop_map.get(grid_pos)
	if crop and crop.is_withered:
		_remove_crop(grid_pos)
		return true
	return false

# ==================== 查询接口 ====================
# 检查指定位置是否有作物
func has_crop(grid_pos: Vector2i) -> bool:
	return crop_map.has(grid_pos)

# 检查指定位置的作物是否成熟
func is_crop_mature(grid_pos: Vector2i) -> bool:
	var crop = crop_map.get(grid_pos)
	return crop != null and crop.is_mature

# 检查指定位置的作物是否枯萎
func is_crop_withered(grid_pos: Vector2i) -> bool:
	var crop = crop_map.get(grid_pos)
	return crop != null and crop.is_withered

# 获取指定位置的作物数据（用于存档或扩展）
func get_crop_at(grid_pos: Vector2i) -> CropData:
	return crop_map.get(grid_pos, null)

# 获取所有作物数据（用于存档）
func get_all_crops() -> Dictionary:
	return crop_map

# 获取作物数量
func get_crop_count() -> int:
	return crop_map.size()

# ==================== 调试 ====================
# 打印所有作物信息（用于调试）
func debug_print_crops():
	print("=== 农场作物列表 ===")
	print("总作物数: ", crop_map.size())
	for pos in crop_map.keys():
		var crop = crop_map[pos]
		print("位置: ", pos, 
			  " | 阶段: ", crop.current_stage,
			  " | 进度: ", crop.growth_progress, "/", crop.plant_data.growth_days,
			  " | 成熟: ", crop.is_mature,
			  " | 偏移: ", crop.plant_data.y_offset)
