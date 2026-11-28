# player.gd
# 玩家控制器 - 处理移动、背包、种植交互
# 适配：War3TileMapLayer（4 子层包装节点）
class_name Player
extends CharacterBody2D

# ==================== UI 引用 ====================
@onready var bag_ui: Control = $GameUI/CanvasLayer/BagUI
@onready var hot_bar_ui: Control = $GameUI/CanvasLayer/HotBarUI

# ==================== 库存 ====================
@export var player_inventory: Inventory

# ==================== 状态机 引用 ====================
@onready var _body_sprite: AnimatedSprite2D = $Skeleton/Body
@onready var _head_sprite: AnimatedSprite2D = $Skeleton/Head
@onready var _eyes_sprite: AnimatedSprite2D = $Skeleton/Eyes
@onready var _hair_sprite: AnimatedSprite2D = $Skeleton/Hair

var _sprites: Array[AnimatedSprite2D]

# ==================== 状态 ====================
var is_bag_open: bool = false
# 坐标参考子层（来自 FarmManager）
var reference_layer: TileMapLayer = null
# 高亮层保持原生 TileMapLayer
var highlight_layer: TileMapLayer = null
var farm_manager: FarmManager = null

# ==================== 种植/高亮 ====================
var is_seed_selected: bool = false
const HIGHLIGHT_SOURCE_ID: int = 0

# ==================== 移动参数 ====================
var speed: int = 150
var move_direction: Vector2 = Vector2.ZERO

# ==================== 动画状态 ====================
var _current_anim: String = ""
var _facing_suffix: String = "s"
const DIRECTION_SUFFIXES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
# 眼睛仅支持这些方向，其余方向隐藏
const EYES_SUPPORTED_SUFFIXES: Array[String] = ["s", "sw", "w", "e", "se"]

# ==================== 初始化 ====================
func _ready():
	farm_manager = FarmManager
	_setup_highlight_layer()
	call_deferred("_deferred_setup")
	_sprites = [_body_sprite, _head_sprite, _eyes_sprite, _hair_sprite]
	_play_animation("idle_s")

	if hot_bar_ui:
		hot_bar_ui.hot_bar_inventory = player_inventory
		hot_bar_ui.hot_bar_ready()

	hot_bar_ui.selector_moved.connect(_on_hotbar_changed)
	bag_ui.bag_closed.connect(_on_bag_closed)
	_on_hotbar_changed(hot_bar_ui.selected_index)

func _play_animation(anim_name: String) -> void:
	if anim_name == _current_anim:
		return
	_current_anim = anim_name

	# 解析出方向后缀（anim_name 形如 "walk_s" / "idle_ne"）
	var suffix := anim_name.get_slice("_", 1)

	for sprite in _sprites:
		# 眼睛：只支持 5 个方向，其余方向隐藏
		if sprite == _eyes_sprite:
			if suffix in EYES_SUPPORTED_SUFFIXES:
				sprite.visible = true
				if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
					sprite.play(anim_name)
			else:
				sprite.visible = false
			continue

		# 其它精灵：正常播放（有则播，无则跳过）
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)

func _direction_to_suffix(dir: Vector2) -> String:
	# 屏幕空间角度：0° = 右(e)，顺时针增加（y 向下）
	var angle := rad_to_deg(dir.angle())
	var idx := int(round(angle / 45.0))
	idx = posmod(idx, 8)
	return DIRECTION_SUFFIXES[idx]

func _update_move_animation() -> void:
	if move_direction.length() > 0.01:
		_facing_suffix = _direction_to_suffix(move_direction.normalized())
		_play_animation("walk_" + _facing_suffix)
	else:
		_play_animation("idle_" + _facing_suffix)

func _deferred_setup():
	await get_tree().process_frame
	# 等 FarmManager 初始化完
	if farm_manager and farm_manager.reference_layer == null:
		await get_tree().process_frame
	if farm_manager and farm_manager.reference_layer:
		reference_layer = farm_manager.reference_layer
	else:
		push_error("player.gd: FarmManager 未提供坐标参考层！")

# 设置高亮层（保持原生 TileMapLayer）
func _setup_highlight_layer():
	var root = get_tree().current_scene
	if not root:
		root = get_tree().root
	highlight_layer = root.find_child("HighlightLayer", true, false) as TileMapLayer
	if not highlight_layer:
		push_error("player.gd: 找不到 HighlightLayer 节点！")
	else:
		highlight_layer.clear()
		_ensure_highlight_tile()

func _ensure_highlight_tile():
	if not highlight_layer or not highlight_layer.tile_set:
		return

	var tile_set = highlight_layer.tile_set
	if tile_set.get_source_count() < 1:
		var texture = _create_highlight_texture(Color.YELLOW)
		var source = TileSetAtlasSource.new()
		source.texture = texture
		source.create_tile(Vector2i(0, 0))
		tile_set.add_source(source)

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
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_bag"):
		toggle_bag()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_seed_selected and reference_layer:
			# 按这次点击的位置选格，避免种到上一帧高亮的地块。
			var mouse_local := reference_layer.make_canvas_position_local(event.position)
			var target_grid := reference_layer.local_to_map(mouse_local)
			if _is_in_planting_area(target_grid):
				_try_plant(target_grid)

	if event is InputEventMouseMotion:
		_update_highlight(event)

	if event is InputEventKey and event.pressed:
		for i in range(10):
			if event.keycode == KEY_1 + i:
				hot_bar_ui.move_selector(i)

		if event.keycode == KEY_K:
			TimeManager.skip_4_steps()
		if event.keycode == KEY_L:
			TimeManager.skip_to_next_day()

# ==================== 高亮系统 ====================
func _on_hotbar_changed(_index: int):
	_update_seed_selected_state()

func _on_bag_closed():
	_update_seed_selected_state()

func _update_seed_selected_state():
	var item = _get_selected_item()
	var was_selected = is_seed_selected
	is_seed_selected = item != null and item.plant_data != null

	if not is_seed_selected:
		if highlight_layer:
			highlight_layer.clear()
	elif not was_selected:
		_update_highlight()

func _update_highlight(event: InputEventMouseMotion = null) -> void:
	if not highlight_layer:
		return
	highlight_layer.clear()

	if not is_seed_selected or not reference_layer or not highlight_layer.tile_set:
		return

	# 鼠标移动时用事件坐标，玩家移动时读取当前光标位置。
	var mouse_local := reference_layer.get_local_mouse_position()
	if event:
		mouse_local = reference_layer.make_canvas_position_local(event.position)
	var target_grid := reference_layer.local_to_map(mouse_local)
	if _is_in_planting_area(target_grid) and highlight_layer.tile_set.has_source(HIGHLIGHT_SOURCE_ID):
		highlight_layer.set_cell(target_grid, HIGHLIGHT_SOURCE_ID, Vector2i(0, 0))

func _is_in_planting_area(target_grid: Vector2i) -> bool:
	# 用同一个瓦片层换算玩家和目标的格子坐标。
	var player_grid := reference_layer.local_to_map(reference_layer.to_local(global_position))
	return farm_manager.is_plantable(target_grid) and farm_manager.is_within_range(player_grid, target_grid)

# ==================== 背包 ====================
func toggle_bag():
	if is_bag_open:
		bag_ui.close_bag()
		is_bag_open = false
		hot_bar_ui.visible = true
		_on_bag_closed()
	else:
		bag_ui.open_bag(player_inventory)
		is_bag_open = true
		hot_bar_ui.visible = false

# ==================== 快捷栏 ====================
func _get_selected_item() -> ItemData:
	var idx = hot_bar_ui.selected_index
	var slot = hot_bar_ui.hot_bar_inventory.slots[idx]
	return slot.item if slot and slot.item else null

# ==================== 种植 ====================
func _try_plant(grid_pos: Vector2i):
	if farm_manager.has_crop(grid_pos):
		return

	var item = _get_selected_item()
	if not item or not item.plant_data:
		_update_seed_selected_state()
		return

	if farm_manager.plant_crop(grid_pos, item.plant_data):
		hot_bar_ui.hot_bar_inventory.use_item(hot_bar_ui.selected_index)
		if highlight_layer:
			highlight_layer.clear()
		_update_seed_selected_state()

# ==================== 移动 ====================
func _physics_process(_delta: float) -> void:
	movement_loop()
	if is_seed_selected:
		_update_highlight()

func movement_loop() -> void:
	move_direction.x = int(Input.is_action_pressed("walk_right")) - int(Input.is_action_pressed("walk_left"))
	move_direction.y = (int(Input.is_action_pressed("walk_down")) - int(Input.is_action_pressed("walk_up"))) / float(2)
	set_velocity(move_direction.normalized() * speed)
	move_and_slide()
	_update_move_animation()
