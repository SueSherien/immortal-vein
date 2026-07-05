# inventory_manager.gd
# 库存管理器 - 管理玩家的背包和快捷栏
extends Resource
class_name Inventory

# ==================== 信号 ====================
signal inventory_update  # 库存变化时触发

# ==================== 数据 ====================
@export var slots: Array[Slot]  # 所有格子

# ==================== 基础操作 ====================
# 移除指定格子的物品
func remove_slot(slot_: Slot):
	var index_ = slots.find(slot_)
	if index_ < 0:
		return
	slots[index_] = Slot.new()
	inventory_update.emit()

# 插入物品到指定格子
func insert_slot(slot_index: int, slot_: Slot):
	slots[slot_index] = slot_
	inventory_update.emit()

# 清空格子
func clear_item(clear_index: int):
	slots[clear_index] = Slot.new()
	inventory_update.emit()

# ==================== 使用物品 ====================
# 使用快捷栏指定索引的物品（消耗1个）
func use_item(use_index: int):
	if use_index < 0 or use_index >= slots.size() or not slots[use_index].item:
		return
	
	var use_slot = slots[use_index]
	
	if use_slot.count > 1:
		use_slot.count -= 1
		inventory_update.emit()
		return
	
	clear_item(use_index)

# 使用工具（预留）
func use_tool(use_index: int):
	pass

# ==================== 添加物品 ====================
# 添加物品到背包，返回是否成功
func add_item(item: ItemData, count: int = 1) -> bool:
	var remaining = count
	
	# 先找同类堆叠
	for i in range(slots.size()):
		var slot = slots[i]
		if slot.item and slot.item.item_id == item.item_id and slot.count < slot.item.max_stack:
			var add = min(remaining, slot.item.max_stack - slot.count)
			slot.count += add
			remaining -= add
			if remaining <= 0:
				inventory_update.emit()
				return true
	
	# 再找空位
	for i in range(slots.size()):
		if not slots[i].item:
			var new_slot = Slot.new()
			new_slot.item = item
			new_slot.count = remaining
			slots[i] = new_slot
			inventory_update.emit()
			return true
	
	# 背包已满
	inventory_update.emit()
	return false
