extends Control

@onready var hot_slot_container: HBoxContainer = $HotBarPanel/MarginContainer/HotSlotContainer
@onready var bag_slot_container: GridContainer = $BagPanel/MarginContainer/BagSlotContainer
@onready var bag_slots: Array = $HotBarPanel/MarginContainer/HotSlotContainer.get_children()\
+ $BagPanel/MarginContainer/BagSlotContainer.get_children()
@onready var slotitem_ = preload("res://ui/slot/slot_item.tscn")

var bag_inventory: Inventory
var mouse_item: SlotItem = null

func _ready() -> void:
	connect_signal()
	close_bag()
	
	for i in range(bag_slots.size()):
		#获取当前循环的UI格子（bag_slots[i]：第i个格子
		var slot = bag_slots[i]
		slot.slot_index = i
	
#循环遍历所有UI格子，每个slot_button都是一个格子钮
func connect_signal():
	for slot_button in bag_slots:
		slot_button.mouse_button_left_press.connect(mouse_left_slot_button.bind(slot_button))
		slot_button.mouse_button_right_press.connect(mouse_right_slot_button.bind(slot_button))
		
#把玩家库存数据同步到UI中，并且根据玩家操作更新
func bag_update():
	if bag_inventory.slots.size() != bag_slots.size():
		return
	#循环遍历所有UI格子（i是索引，从0开始，注意库存格子数量要跟UI显示的格子数量同步！）
	for i in range(bag_slots.size()):
		var inventory_slots: Slot = bag_inventory.slots[i]
		#检查当前格子是否为空，防止报错
		if !inventory_slots:
			#if bag_slots[i].slot_button_slot_item:
				#bag_slots[i].slot_button_slot_item.queue_free()
				#避免残留引用
				#bag_slots[i].slot_button_slot_item = null
			bag_slots[i].reset_color()
			continue
			
		if !inventory_slots.item:
			#if bag_slots[i].slot_button_slot_item:
				#bag_slots[i].slot_button_slot_item.queue_free()
				#避免残留引用
				#bag_slots[i].slot_button_slot_item = null
				#bag_slots[i].reset_color()
			bag_slots[i].clear_slot()
			continue
			
		var slot_item: SlotItem = bag_slots[i].slot_button_slot_item
		
		#如果UI格子里没有物品示节点，就实例化一个slot_item插入
		if !slot_item:
			slot_item = slotitem_.instantiate()
			bag_slots[i].insert(slot_item)
		#把库存格子的数据inventory_slots赋值给显示节点的
		slot_item.slot_ = inventory_slots
		#调用物品显示节点的更新函数，让它显示物品图标和数量
		slot_item.slot_item_update()

func set_player_inventory(player_inventory: Inventory):
	bag_inventory = player_inventory
	if bag_inventory:
		bag_update()

func open_bag(player_inventory: Inventory):
	set_player_inventory(player_inventory)
	
	if bag_inventory.inventory_update.is_connected(bag_update):
		bag_inventory.inventory_update.disconnect(bag_update)
		
	bag_inventory.inventory_update.connect(bag_update)

	for slot_button in bag_slots:
		slot_button.slot_inventory = bag_inventory
		show()
		
func close_bag():
	hide()

#鼠标左键点击格子函数，判断是抓取还是放入
func mouse_left_slot_button(slot_button):
	#点击格子是空的，鼠标有物品，执行放入
	if slot_button.is_empty() and mouse_item:
		insert_item_in_slot(slot_button)
	#点击格子有物品，鼠标是空的，执行抓取
	elif !slot_button.is_empty() and !mouse_item:
		take_item_from_slot(slot_button)
	#点击格子有物品，且鼠标也有物品，准备堆叠或者交换
	elif !slot_button.is_empty() and mouse_item:
		if slot_button.slot_button_slot_item.slot_.item.item_id != mouse_item.slot_.item.item_id:
		#交换物品函数
			swap_items(slot_button)
		#物品最大堆叠为1时进行交换
		elif slot_button.slot_button_slot_item.slot_.item.item_id == mouse_item.slot_.item.item_id:
			if slot_button.slot_button_slot_item.slot_.item.max_stack == 1:
				swap_items(slot_button)
			#物品堆叠判断
			else:
				stack_items(slot_button)
		else:
			return
	else:
		return
			
#鼠标右键抓取一半或者放入一个
func mouse_right_slot_button(slot_button):
	#放入时如果品不同，执行换取物品函数
	if !slot_button.is_empty() and mouse_item:
		if slot_button.slot_button_slot_item.slot_.item.item_id != mouse_item.slot_.item.item_id:
			#交换物品函数
			swap_items(slot_button)
		else:
			put_one_item_to_slot(slot_button)
	#点击格子有物品，鼠标是空的，执行抓取
	elif !slot_button.is_empty() and !mouse_item:
		take_half_items(slot_button)
	
	#点击的格子是空的，标有物品
	elif slot_button.is_empty() and mouse_item:
		put_one_item_to_slot(slot_button)
	
	else:
		return
		
func put_one_item_to_slot(slot_button):
	#调用前格子的put_one_item函数，传入物品的Slot数据，判断是否放入成功
	var success = slot_button.put_one_item(mouse_item.slot_)

	#如果放入成功，处理鼠标中的物品
	if success:
		if mouse_item.slot_.count <= 0:
			remove_child(mouse_item)
			mouse_item.queue_free()
			mouse_item = null
	
	#如果鼠标上还有剩余物品的情况
		else:
			#更新鼠标物品显示
			mouse_item.slot_item_update()
	#发送库存更新信号，通知UI同步显示更新，确保格子，鼠标物品数量和库存一致
	bag_inventory.inventory_update.emit()
	
	
#鼠标右键抓取一半函数
func take_half_items(slot_button):
	#如果格子只有1个物品，直接抓取并返回
	if slot_button.slot_button_slot_item.slot_.count == 1:
		take_item_from_slot(slot_button)
		return
	#获取当前格子原物品显示节点
	var original_item: SlotItem = slot_button.slot_button_slot_item
	#获取原物品总数
	var original_count = original_item.slot_.count
	var take_count = ceil(original_count / 2.0)
	#创建的节点用于跟随鼠标
	var new_item = slotitem_.instantiate()
	#创建新的slot对象（深拷贝）
	var new_slot = Slot.new()
	
	#新物品类型与原物品保持一致
	new_slot.item = original_item.slot_.item
	#数量等于take_count
	new_slot.count = take_count
	#赋予新物品节点，关联物品类型和数量
	new_item.slot_ = new_slot
	#新原物品数量
	original_item.slot_.count = original_count - take_count
	
	#设置鼠标物品，让新创建的物品（原物品一半）跟随鼠标
	mouse_item = new_item
	add_child(mouse_item)#把新物品添加为bag_ui的子节点，避免被遮挡
	item_follow_mouse()
	
	#更新物品显示，让格子里，鼠标上的物品数量实时显示正确
	if original_item: original_item.slot_item_update()
	if mouse_item: mouse_item.slot_item_update()
	
	#发送库存更新信号，通知UI同步显示更新，确保格子，鼠标物品数量和库存一致
	bag_inventory.inventory_update.emit()
	
#从格子抓取物品函数
func take_item_from_slot(slot_button):
	mouse_item = slot_button.take_item()
	if mouse_item:
		add_child(mouse_item)
		item_follow_mouse()

#物品跟随鼠标函数
func item_follow_mouse():
	if !mouse_item:
		return
	mouse_item.global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	item_follow_mouse()
#放入物品函数
func insert_item_in_slot(slot_button):
	#临时记录鼠标左键中的物品，避免丢失物品引用
	var item_ = mouse_item
	#让物品开鼠标，准备放入格子
	remove_child(mouse_item)
	#重置鼠标状态
	mouse_item = null
	#调用当前空格子（slot_button）的insert函数，把物品放进格子
	slot_button.insert(item_)

#物品交换函数
func swap_items(slot_button):
	#调用当前格子的take_item函数，取出物品赋值给临时变量one_time
	var one_item = slot_button.take_item()
	insert_item_in_slot(slot_button)
	mouse_item = one_item
	add_child(mouse_item)
	item_follow_mouse()

#物品堆叠函数
func stack_items(slot_button):
	var one_item: SlotItem = slot_button.slot_button_slot_item
	var max_stack_count = one_item.slot_.item.max_stack
	var total_count = one_item.slot_.count + mouse_item.slot_.count
	
	if one_item.slot_.count == max_stack_count:
		return
	
	if total_count <= max_stack_count:
		one_item.slot_.count = total_count
		remove_child(mouse_item)
		mouse_item.queue_free()
		mouse_item = null
		
	else:
		one_item.slot_.count = max_stack_count
		mouse_item.slot_.count = total_count - max_stack_count
	
	#更新物品显示，让格子里，鼠标上的物品数量实时显示正确
	if one_item: one_item.slot_item_update()
	if mouse_item: mouse_item.slot_item_update()
		
	#发送库存更新信号，通知UI同步显示更新，确保格子，鼠标物品数量和库存一致
	bag_inventory.inventory_update.emit()
		
		
