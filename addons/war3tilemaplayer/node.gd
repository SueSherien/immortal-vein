@tool
class_name War3TileMapLayer
extends Node2D

const SUB_NAMES = ["_layer_0", "_layer_1", "_layer_2", "_layer_3"]

# 与原生 TileMapLayer 同名的属性，编辑器据此识别为可编辑瓦片地图
# setter 自动把 tile_set 同步到所有子层
@export var tile_set: TileSet:
	set(value):
		tile_set = value
		_sync_tileset_to_sublayers()

# 可选：保留旧属性名作为别名，方便老代码/资源迁移（不推荐长期用）
# @export var war3_custom_tile_set: TileSet:
# 	get: return tile_set
# 	set(value): tile_set = value

func _ready() -> void:
	# 编辑器里如果子层已存在，确保 tile_set 同步
	if tile_set:
		_sync_tileset_to_sublayers()

func _sync_tileset_to_sublayers() -> void:
	for layer_name in SUB_NAMES:
		var sub = get_node_or_null(layer_name)
		if sub is TileMapLayer:
			sub.tile_set = tile_set

# 创建子层级
func build_all_layers():
	for layer_name in SUB_NAMES:
		# 避免重复创建
		if get_node_or_null(layer_name) != null:
			continue
		var layer = TileMapLayer.new()
		layer.name = layer_name
		layer.collision_enabled = false
		layer.tile_set = tile_set   # 创建时即同步
		add_child(layer)
		# 编辑器场景中设置 owner，便于保存到场景文件
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			layer.set_owner(get_tree().edited_scene_root)

# 获取所有的子层
func get_corner_layers() -> Array:
	var _sub_layers: Array = []
	for child in get_children():
		if child is TileMapLayer and SUB_NAMES.has(child.name):
			_sub_layers.append(child)
	return _sub_layers

# 是否已创建所有的子层
func has_all_corner_layers() -> bool:
	for n in SUB_NAMES:
		if get_node_or_null(n) == null:
			return false
	return true

# 设置子层的 tileset（保留兼容接口）
func set_sublayers_tileset(ts: TileSet):
	tile_set = ts
	_sync_tileset_to_sublayers()
