# item_data.gd
# 物品数据资源 - 所有物品的基础
extends Resource
class_name ItemData

# ==================== 基础属性 ====================
@export var item_id: int               # 物品唯一ID
@export var item_name: String          # 物品名称
@export var item_texture: Texture2D    # 物品图标
@export var item_quality: int = 0      # 品质等级
@export var max_stack: int = 99        # 最大堆叠数量
@export var description: String = ""   # 物品描述

# ==================== 扩展引用（组合模式） ====================
# 如果该物品是种子，引用对应的作物数据
@export var plant_data: PlantData = null

# 如果该物品是装饰物，引用对应的装饰数据
@export var decoration_data: DecorationData = null

# 未来可扩展：工具数据、食物数据等
