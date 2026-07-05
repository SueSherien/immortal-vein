# slot.gd
# 库存格子数据 - 存储物品和数量
extends Resource
class_name Slot

# ==================== 数据 ====================
@export var item: ItemData = null   # 格子中的物品
@export var count: int = 0          # 物品数量
