# ============================================================================
# farm_manager.gd
# 全局农场管理器 - 管理所有作物的种植、生长、收获
# 适配：War3TileMapLayer（4 子层包装节点）
# 场景结构：
#   场景根
#   ├── Tilemap (Node2D)
#   │   ├── FieldDry (War3TileMapLayer)
#   │   ├── Dirt (War3TileMapLayer)
#   │   └── ...
# ============================================================================
extends Node

# ==================== 作物数据类 ====================
class CropData:
	var position: Vector2i
	var plant_data: PlantData
	var current_stage: int = 0
	var growth_progress: int = 0
	var is_mature: bool = false
	var is_withered: bool = false
	var crop_node: Node2D
	var harvest_count: int = 0

# ==================== 信号 ====================
signal crop_planted(position: Vector2i)
signal crop_harvested(position: Vector2i)
signal crop_withered(position: Vector2i)

# ==================== 引用 ====================
var crop_map: Dictionary = {}

# 所有可种植的 War3TileMapLayer（FieldDry、Dirt 等）
var plantable_layers: Array[War3TileMapLayer] = []
# 坐标参考层（取第一个可种植层的第 0 子层）
var reference_layer: TileMapLayer = null
# 兼容旧字段名，指向 reference_layer
var tilemap_layer: War3TileMapLayer = null

var crops_container: Node2D

const CROP_SCENE = "res://scenes/objects/plants/crop.tscn"

# 可种植图层候选名（按优先级）
const PLANTABLE_LAYER_NAMES: Array[String] = ["FieldDry", "Field", "Dirt", "Grass"]

# ==================== 初始化 ====================
func _ready():
	if not TimeManager.day_ended.is_connected(_on_day_end):
		TimeManager.day_ended.connect(_on_day_end)
	# 延迟两帧，确保场景树完全就绪
	call_deferred("_deferred_setup")

func _deferred_setup():
	await get_tree().process_frame
	_setup_references()

func _setup_references():
	var root = get_tree().current_scene
	if not root:
		# 极端情况：current_scene 为空，用 scene tree 根
		root = get_tree().root

	# --- 查找所有 War3TileMapLayer ---
	var all_layers: Array[War3TileMapLayer] = []
	_collect_war3_layers(root, all_layers)

	if all_layers.is_empty():
		push_error("farm_manager: 场景中找不到任何 War3TileMapLayer！")
		return

	# --- 按候选名筛选可种植层 ---
	plantable_layers.clear()
	for layer_name in PLANTABLE_LAYER_NAMES:
		for layer in all_layers:
			if layer.name == layer_name and not plantable_layers.has(layer):
				plantable_layers.append(layer)
	# 如果候选名都没匹配上，退化为：全部 War3TileMapLayer 都当作可种植层
	if plantable_layers.is_empty():
		push_warning("farm_manager: 未匹配到候选名，使用全部 War3TileMapLayer 作为可种植层")
		plantable_layers = all_layers.duplicate()

	# --- 确保子层已创建 ---
	for layer in plantable_layers:
		if not layer.has_all_corner_layers():
			push_warning("farm_manager: %s 子层未创建，自动创建" % layer.name)
			layer.build_all_layers()

	# --- 建立坐标参考层 ---
	reference_layer = null
	for layer in plantable_layers:
		var sub = layer.get_corner_layers()
		if not sub.is_empty() and sub[0] is TileMapLayer:
			reference_layer = sub[0]
			tilemap_layer = layer
			break

	if not reference_layer:
		push_error("farm_manager: 无法建立坐标参考层（子层缺失）")
		return

	# --- 获取或创建作物容器 ---
	crops_container = root.find_child("Crops", true, false)
	if not crops_container:
		crops_container = Node2D.new()
		crops_container.name = "Crops"
		root.add_child(crops_container)

	print("[farm_manager] 可种植层: ", plantable_layers.map(func(l): return l.name))

# 递归收集所有 War3TileMapLayer
func _collect_war3_layers(node: Node, out: Array[War3TileMapLayer]):
	for child in node.get_children():
		if child is War3TileMapLayer:
			out.append(child)
		_collect_war3_layers(child, out)

# ==================== 地形检测 ====================
# 检查指定格子是否为可种植地形
# 规则：该格子所有存在 ground_type 数据的子层，其 ground_type 都必须是 dry_field/wet_field
# 只要有任何一层是其他类型，就不可种植；至少要有一层是 dry_field/wet_field 才算种植地形
func is_plantable(grid_pos: Vector2i) -> bool:
	if plantable_layers.is_empty():
		return false

	var found_plantable := false

	for wlayer in plantable_layers:
		if not is_instance_valid(wlayer):
			continue
		var sub_layers = wlayer.get_corner_layers()
		for sub in sub_layers:
			if not is_instance_valid(sub):
				continue
			var tile_data = sub.get_cell_tile_data(grid_pos)
			if not tile_data:
				continue
			var ground_type = tile_data.get_custom_data("ground_type")
			if ground_type == "dry_field" or ground_type == "wet_field":
				found_plantable = true
			else:
				# 存在其他类型，直接判定不可种植
				return false

	return found_plantable

# ==================== 距离检测 ====================
func is_within_range(player_grid: Vector2i, target_grid: Vector2i) -> bool:
	var dx = target_grid.x - player_grid.x
	var dy = target_grid.y - player_grid.y
	return (
	(dx == -2 and dy == 0)  or
	(dx == -1 and dy == -1) or
	(dx == -1 and dy == 1)  or
	(dx == 0 and dy == -2)  or
	(dx == 0 and dy == 2)   or
	(dx == 1 and dy == -1)  or
	(dx == 1 and dy == 1)   or
	(dx == 2 and dy == 0)
	)

# ==================== 种植 ====================
func plant_crop(grid_pos: Vector2i, plant_data: PlantData) -> bool:
	if crop_map.has(grid_pos):
		return false
	if not plant_data or not reference_layer:
		return false
	if plant_data.growth_stage_textures.is_empty():
		push_error("plant_data: 阶段贴图为空！")
		return false

	var crop = CropData.new()
	crop.position = grid_pos
	crop.plant_data = plant_data

	crop.crop_node = _create_crop_node(grid_pos, plant_data, 0)
	if not crop.crop_node:
		return false

	crop_map[grid_pos] = crop
	crop_planted.emit(grid_pos)
	return true

func _create_crop_node(grid_pos: Vector2i, plant_data: PlantData, stage: int) -> Node2D:
	var scene = load(CROP_SCENE)
	if not scene:
		push_error("farm_manager: 无法加载作物场景: %s" % CROP_SCENE)
		return null

	var instance = scene.instantiate() as Node2D
	if not instance:
		push_error("farm_manager: 作物场景实例化失败")
		return null

	# 用参考层做坐标转换
	instance.position = reference_layer.map_to_local(grid_pos)

	var sprite = instance.get_node("Sprite") as Sprite2D
	if not sprite:
		for child in instance.get_children():
			if child is Sprite2D:
				sprite = child
				break

	if sprite and plant_data:
		sprite.position.y = plant_data.y_offset
		var tex = plant_data.get_stage_texture(stage)
		if tex:
			sprite.texture = tex
		else:
			push_warning("farm_manager: 作物阶段 %d 贴图为空" % stage)

	if crops_container:
		crops_container.add_child(instance)
	else:
		get_tree().current_scene.add_child(instance)

	return instance

# ==================== 生长 ====================
func _on_day_end():
	for pos in crop_map.keys():
		var crop = crop_map[pos]
		if crop.is_withered or crop.is_mature:
			continue

		crop.growth_progress += 1

		if crop.growth_progress >= crop.plant_data.growth_days:
			crop.is_mature = true
			crop.current_stage = 3
			_update_display(pos)
		else:
			var new_stage = _calc_stage(crop)
			if new_stage != crop.current_stage:
				crop.current_stage = new_stage
				_update_display(pos)

func _calc_stage(crop: CropData) -> int:
	var ratio = float(crop.growth_progress) / float(crop.plant_data.growth_days)
	if ratio >= 0.75:
		return 2
	elif ratio >= 0.4:
		return 1
	return 0

func _update_display(grid_pos: Vector2i):
	var crop = crop_map.get(grid_pos)
	if not crop or not crop.crop_node:
		return

	var sprite = crop.crop_node.get_node("Sprite") as Sprite2D
	if not sprite:
		return

	if crop.plant_data:
		sprite.position.y = crop.plant_data.y_offset

	var tex: Texture2D
	if crop.is_withered:
		tex = crop.plant_data.withered_texture
	elif crop.is_mature:
		tex = crop.plant_data.get_stage_texture(3)
	else:
		tex = crop.plant_data.get_stage_texture(crop.current_stage)

	if tex:
		sprite.texture = tex
	else:
		push_warning("farm_manager: 作物 %s 贴图为空" % grid_pos)

# ==================== 收获 ====================
func harvest_crop(grid_pos: Vector2i) -> ItemData:
	var crop = crop_map.get(grid_pos)
	if not crop or not crop.is_mature:
		return null

	var item = crop.plant_data.harvest_item
	if not item:
		push_warning("farm_manager: 作物 %s 没有设置收获物品" % grid_pos)
		return null

	if crop.plant_data.harvest_type == 0:
		_remove_crop(grid_pos)
	else:
		crop.is_mature = false
		crop.growth_progress = 1
		crop.current_stage = 1
		crop.harvest_count += 1
		_update_display(grid_pos)

	crop_harvested.emit(grid_pos)
	return item

func _remove_crop(grid_pos: Vector2i):
	var crop = crop_map.get(grid_pos)
	if crop:
		if crop.crop_node:
			crop.crop_node.queue_free()
		crop_map.erase(grid_pos)

# ==================== 铲除枯萎 ====================
func remove_withered(grid_pos: Vector2i) -> bool:
	var crop = crop_map.get(grid_pos)
	if crop and crop.is_withered:
		_remove_crop(grid_pos)
		return true
	return false

# ==================== 查询接口 ====================
func has_crop(grid_pos: Vector2i) -> bool:
	return crop_map.has(grid_pos)

func is_crop_mature(grid_pos: Vector2i) -> bool:
	var crop = crop_map.get(grid_pos)
	return crop != null and crop.is_mature

func is_crop_withered(grid_pos: Vector2i) -> bool:
	var crop = crop_map.get(grid_pos)
	return crop != null and crop.is_withered

func get_crop_at(grid_pos: Vector2i) -> CropData:
	return crop_map.get(grid_pos, null)

func get_all_crops() -> Dictionary:
	return crop_map

func get_crop_count() -> int:
	return crop_map.size()

# ==================== 调试 ====================
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
