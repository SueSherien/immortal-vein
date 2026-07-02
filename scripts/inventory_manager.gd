extends Resource

#给背包起一个类名，后续控制背包都靠这个类
class_name Inventory

#库存更新信号，数据变化时，给UI发送信号通知更新
signal inventory_update

#定义一个Slot类型的数组slots，默认空数组
#数组是背包容器，所有格子都存在这里
@export var slots: Array[Slot]

#移除库存格子物品
func remove_slot(slot__: Slot):
	var index_ = slots.find(slot__)
	if index_ < 0: return
	#把索引位置格子替换成一个新的空格子Slot
	slots[index_] = Slot.new()
	#发送库存更新信号，通知UI同步更新
	inventory_update.emit()
	
#插入物品到指定库存格子的函数，背包放入物品时调用这个函数更新库存
func insert_slot(slot_index: int, slot__: Slot):
	#把传入的物品格子数据(slot__)赋值给slots数组
	slots[slot_index] = slot__
	#发送更新信号，通知UI库存同步更新
	inventory_update.emit()
	
#使用快捷栏对应索引的物品，use_index：参数，快捷栏格子的索引
func use_item(use_index: int):
	#容错判断，避免报错
	if use_index < 0 or use_index >= slots.size() or !slots[use_index].item:
		return
	
	#获取要使用的库存格子（快捷栏索引对应的实际库存格子）
	var use_slot = slots[use_index]
	
	#物品数量大于1，只使用1个，不删除物品
	if use_slot.count > 1:
		use_slot.count -= 1
		inventory_update.emit()
		return
		
	clear_item(use_index)
	
func use_tool(use_index: int):
	pass
		
func clear_item(clear_index: int):
	#把索引位置格子替换成一个新的空格子Slot
	slots[clear_index] = Slot.new()
	#发送库存更新信号，通知UI同步更新
	inventory_update.emit()
	
	
