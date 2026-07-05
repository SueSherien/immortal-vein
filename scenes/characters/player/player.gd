# player.gd
# 玩家控制器 - 处理移动、背包、种植交互
# 依赖：FarmManager (自动加载), TimeManager (自动加载), Inventory (资源)
class_name Player
extends CharacterBody2D

# ==================== UI 引用 ====================
# 背包UI - 显示玩家背包内容
@onready var bag_ui: Control = $GameUI/CanvasLayer/BagUI
# 快捷栏UI - 显示快捷栏物品，支持数字键切换
@onready var hot_bar_ui: Control = $GameUI/CanvasLayer/HotBarUI

# ==================== 库存 ====================
# 玩家背包库存数据，在编辑器中设置
@export var player_inventory: Inventory

# ==================== 状态 ====================
# 背包是否打开
var is_bag_open: bool = false
# 地面瓦片地图层（用于坐标转换和地形检测）
var tilemap_layer: TileMapLayer
# 高亮显示层（独立图层，显示在游戏世界最上层）
var highlight_layer: TileMapLayer
# 农场管理器引用（自动加载）
var farm_manager: FarmManager

# ==================== 种植/高亮 ====================
# 当前是否选中了种子（快捷栏中有种子物品）
var is_seed_selected: bool = false
# 当前鼠标指向的有效种植目标格子（坐标）
var valid_target_cell: Vector2i = Vector2i()
# 高亮瓦片在 TileSet 中的 Source ID（0 表示第一个瓦片）
const HIGHLIGHT_SOURCE_ID: int = 0

# ==================== 移动参数 ====================
# 玩家移动速度（像素/秒）
var speed: int = 150
# 当前移动方向向量
var move_direction: Vector2 = Vector2.ZERO

# ==================== 初始化 ====================
func _ready():
	# 获取地图层引用
	_setup_tilemap()
	# 获取高亮层引用
	_setup_highlight_layer()
	# 获取农场管理器（自动加载）
	farm_manager = FarmManager

	# 初始化快捷栏
	if hot_bar_ui:
		hot_bar_ui.hot_bar_inventory = player_inventory
		hot_bar_ui.hot_bar_ready()

	# 监听快捷栏选择变化
	hot_bar_ui.selector_moved.connect(_on_hotbar_changed)
	# 监听背包关闭事件（背包关闭后重新检查快捷栏状态）
	bag_ui.bag_closed.connect(_on_bag_closed)
	# 初始检查快捷栏是否选中种子
	_on_hotbar_changed(hot_bar_ui.selected_index)

# 获取 TileMapLayer 引用
func _setup_tilemap():
	var root = get_tree().current_scene

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
		push_error("player.gd: 找不到 TileMapLayer 节点！")

# 设置高亮层
func _setup_highlight_layer():
	var root = get_tree().current_scene
	# 查找名为 "HighlightLayer" 的 TileMapLayer 节点
	highlight_layer = root.find_child("HighlightLayer", true, false) as TileMapLayer
	if not highlight_layer:
		push_error("player.gd: 找不到 HighlightLayer 节点！")
	else:
		# 清空高亮层（初始状态无高亮）
		highlight_layer.clear()
		# 确保高亮层有可用的瓦片
		_ensure_highlight_tile()

# 确保高亮层有瓦片（如果没有则动态创建）
func _ensure_highlight_tile():
	if not highlight_layer or not highlight_layer.tile_set:
		return

	var tile_set = highlight_layer.tile_set
	# 如果 TileSet 中没有瓦片，创建一个黄色边框的瓦片
	if tile_set.get_source_count() < 1:
		var texture = _create_highlight_texture(Color.YELLOW)
		var source = TileSetAtlasSource.new()
		source.texture = texture
		source.create_tile(Vector2i(0, 0))
		tile_set.add_source(source)

# 生成高亮贴图（黄色边框）
func _create_highlight_texture(color: Color) -> Texture2D:
	var size = 32
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var border = 3
	for x in range(size):
		for y in range(size):
			if x < border or x >= size - border or y < border or y >= size - border:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

# ==================== 输入处理 ====================
func _input(event):
	# 按 B 键切换背包
	if event.is_action_pressed("toggle_bag"):
		toggle_bag()

	# 鼠标左键点击 - 种植
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 只有选中种子且存在有效目标格子时才能种植
		if is_seed_selected and valid_target_cell != Vector2i(-1, -1):
			_try_plant(valid_target_cell)

	# 鼠标移动 - 更新悬停高亮
	if event is InputEventMouseMotion:
		_update_highlight()

	# 快捷键 1-0 切换快捷栏
	if event is InputEventKey and event.pressed:
		for i in range(10):
			if event.keycode == KEY_1 + i:
				hot_bar_ui.move_selector(i)

		# 调试快捷键（保留方便测试）
		if event.keycode == KEY_K:
			TimeManager.skip_4_steps()
		if event.keycode == KEY_L:
			TimeManager.skip_to_next_day()

# ==================== 高亮系统 ====================
# 当快捷栏选择变化时调用
func _on_hotbar_changed(_index: int):
	_update_seed_selected_state()

# 当背包关闭时调用（重新检查快捷栏状态）
func _on_bag_closed():
	_update_seed_selected_state()

# 更新种子选中状态
func _update_seed_selected_state():
	var item = _get_selected_item()
	var was_selected = is_seed_selected
	is_seed_selected = item and item.plant_data != null

	if not is_seed_selected:
		# 取消选中种子，清除高亮
		valid_target_cell = Vector2i(-1, -1)
		highlight_layer.clear()
	elif not was_selected:
		# 从无到有选中种子，立即更新高亮
		_update_highlight()

# 更新高亮显示
func _update_highlight():
	# 先清空旧高亮
	highlight_layer.clear()
	valid_target_cell = Vector2i(-1, -1)

	# 未选中种子或无地图层则返回
	if not is_seed_selected or not tilemap_layer:
		return

	# 获取鼠标在游戏世界中的位置
	var mouse_pos = get_global_mouse_position()

	# === 等轴测坐标修正 ===
	# 在等轴测地图中，鼠标点击格子的下半部分时，local_to_map() 可能返回下方相邻格子
	# 将检测点向上偏移 30% 格子高度，使点击更准确
	var tile_size = tilemap_layer.tile_set.tile_size
	var offset = Vector2(0, tile_size.y * 0.3)
	var target_grid = tilemap_layer.local_to_map(mouse_pos - offset)
	var player_grid = tilemap_layer.local_to_map(global_position)

	# 检查目标格子是否满足种植条件：
	if farm_manager.is_plantable(target_grid) and farm_manager.is_within_range(player_grid, target_grid):
		valid_target_cell = target_grid
		if highlight_layer.tile_set and highlight_layer.tile_set.get_source_count() > HIGHLIGHT_SOURCE_ID:
			highlight_layer.set_cell(target_grid, HIGHLIGHT_SOURCE_ID, Vector2i(0, 0))

# ==================== 背包 ====================
# 切换背包打开/关闭状态
func toggle_bag():
	if is_bag_open:
		# 关闭背包：隐藏背包UI，显示快捷栏
		bag_ui.close_bag()
		is_bag_open = false
		hot_bar_ui.visible = true
		# 背包关闭后重新检查快捷栏状态（种子可能被移走）
		_on_bag_closed()
	else:
		# 打开背包：显示背包UI，隐藏快捷栏
		bag_ui.open_bag(player_inventory)
		is_bag_open = true
		hot_bar_ui.visible = false

# ==================== 快捷栏 ====================
# 获取快捷栏当前选中的物品
func _get_selected_item() -> ItemData:
	var idx = hot_bar_ui.selected_index
	var slot = hot_bar_ui.hot_bar_inventory.slots[idx]
	return slot.item if slot and slot.item else null

# ==================== 种植 ====================
# 尝试在指定格子种植作物
func _try_plant(grid_pos: Vector2i):
	# 检查该位置是否已有作物
	if farm_manager.has_crop(grid_pos):
		return

	# 获取当前选中的物品
	var item = _get_selected_item()
	if not item or not item.plant_data:
		# 如果选中的物品不再是种子，更新状态并返回
		_update_seed_selected_state()
		return

	# 调用农场管理器执行种植
	if farm_manager.plant_crop(grid_pos, item.plant_data):
		# 种植成功：消耗一个种子
		hot_bar_ui.hot_bar_inventory.use_item(hot_bar_ui.selected_index)
		# 清除高亮
		valid_target_cell = Vector2i(-1, -1)
		highlight_layer.clear()
		# 种植后重新检查快捷栏状态（种子可能已用完）
		_update_seed_selected_state()

# ==================== 移动 ====================
func _physics_process(_delta: float) -> void:
	movement_loop()
	# 如果选中种子，每帧更新高亮（处理玩家移动后距离变化）
	if is_seed_selected:
		_update_highlight()

# 移动逻辑循环
func movement_loop() -> void:
	move_direction.x = int(Input.is_action_pressed("walk_right")) - int(Input.is_action_pressed("walk_left"))
	move_direction.y = (int(Input.is_action_pressed("walk_down")) - int(Input.is_action_pressed("walk_up"))) / float(2)
	set_velocity(move_direction.normalized() * speed)
	move_and_slide()
