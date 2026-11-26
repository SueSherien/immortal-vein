# decoration_data.gd
# 装饰物数据资源 - 定义装饰物的放置属性
extends Resource
class_name DecorationData

# ==================== 放置属性 ====================
@export var place_scene: PackedScene         # 放置到地图上的场景
@export var place_on_ground_types: Array[String] = ["dry_field", "wet_field"]  # 允许放置的地面类型
@export var occupy_size: Vector2i = Vector2i(1, 1)  # 占地大小（格子数）
@export var can_rotate: bool = false         # 是否可旋转
# 可扩展其他装饰属性
