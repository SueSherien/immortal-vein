extends Button

signal mouse_button_left_press
signal mouse_button_right_press

@onready var slot_background: ColorRect = $SlotBackGround
@onready var center_container: CenterContainer = $SlotBackGround/CenterContainer

#存储当前格子关联的库存（和UI传入的库存一致）
var slot_inventory: Inventory
#当前格子对应的库存索引位置
var slot_index: int
#定义变量：储存当前格子里的物品显示节点（SlotItem类型，对应slot_item）
var slot_button_slot_item : SlotItem

func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	reset_color()
	
func reset_color(): #重置格子背景函数
	slot_background.color = Color(0.961, 0.945, 0.902, 0.0)
	
func insert(SI: SlotItem):
	slot_button_slot_item = SI
	slot_background.color = Color(0.961, 0.945, 0.902, 1.0)
	center_container.add_child(slot_button_slot_item)
	
	if !slot_button_slot_item.slot_:
		return
	#调用库存的insert_slot函数，同步插入物品到库存
	slot_inventory.insert_slot(slot_index, slot_button_slot_item.slot_)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			mouse_button_left_press.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			mouse_button_right_press.emit()
			
#抓取物品函数（被tools_bag_ui调用，取出格子内物品）
func take_item():
	#赋值给临时变量take_item_
	var take_item_ = slot_button_slot_item
	#库存里的物品被抓走，库存格子清空
	slot_inventory.remove_slot(slot_button_slot_item.slot_)
	
	#让格子中的物品移除节点，准备跟随鼠标
	if center_container.get_child_count() != 0:
		center_container.remove_child(slot_button_slot_item)
	slot_button_slot_item = null
	reset_color()
	return take_item_

func is_empty():
	#如果slot_button_slot_item没有物品，返回true
	return !slot_button_slot_item

#点击右键放入1个物品，函数返回值是bool，true=成功，false=失败
func put_one_item(mouse_slot: Slot) -> bool:
	#当格子是空的，直接放入个物品
	if is_empty():
		#创建新的Slot对象，深拷贝，避免和鼠标中的物品冲突
		var new_slot = Slot.new()
		#新物品类型，和鼠标物品一致
		new_slot.item = mouse_slot.item
		#只放入1个
		new_slot.count = 1
		
		var new_slot_item = preload("res://ui/slot/slot_item.tscn").instantiate()
		#给新物品节点设置Slot数据（物品和数量）
		new_slot_item.slot_ = new_slot
		#调用格子的insert函数，把新物品插入格子（ui显示）
		insert(new_slot_item)
		#减少鼠标物品数量
		mouse_slot.count -= 1
		
		return true
		
	#格子不为空，判断能否放入1个物品
	else:
		#获取当前格子已有的物品数据（Slot）
		var existing_slot = slot_button_slot_item.slot_
		
		#判断鼠标和格子内的物品id是否相同
		if existing_slot.item.item_id == mouse_slot.item.item_id:
			#判断鼠标和格子内的物品数量
			if existing_slot.count < existing_slot.item.max_stack:
				existing_slot.count += 1
				mouse_slot.count -= 1
				
				return true
				
	return false
		
func clear_slot():
	if slot_button_slot_item:
		#让格子中的物品移除节点，准备跟随鼠标
		center_container.remove_child(slot_button_slot_item)
		slot_button_slot_item = null
	reset_color()
		
		
		
		
		
		
