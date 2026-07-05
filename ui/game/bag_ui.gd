# bag_ui.gd
# 背包UI - 管理背包的显示和交互
extends Control

@onready var hot_slot_container: HBoxContainer = $HotBarPanel/MarginContainer/HotSlotContainer
@onready var bag_slot_container: GridContainer = $BagPanel/MarginContainer/BagSlotContainer
@onready var bag_slots: Array = $HotBarPanel/MarginContainer/HotSlotContainer.get_children() + $BagPanel/MarginContainer/BagSlotContainer.get_children()
@onready var slotitem_ = preload("res://ui/slots/slot_item.tscn")

var bag_inventory: Inventory
var mouse_item: SlotItem = null

# ==================== 信号 ====================
signal bag_closed  # 新增：背包关闭信号

# ==================== 生命周期 ====================
func _ready():
	connect_signal()
	close_bag()
	for i in range(bag_slots.size()):
		bag_slots[i].slot_index = i

func connect_signal():
	for slot_button in bag_slots:
		slot_button.mouse_button_left_press.connect(mouse_left_slot_button.bind(slot_button))
		slot_button.mouse_button_right_press.connect(mouse_right_slot_button.bind(slot_button))

# ==================== 背包更新 ====================
func bag_update():
	if bag_inventory.slots.size() != bag_slots.size():
		return
	
	for i in range(bag_slots.size()):
		var inventory_slots: Slot = bag_inventory.slots[i]
		
		if not inventory_slots or not inventory_slots.item:
			bag_slots[i].clear_slot()
			continue
		
		var slot_item: SlotItem = bag_slots[i].slot_button_slot_item
		if not slot_item:
			slot_item = slotitem_.instantiate()
			bag_slots[i].insert(slot_item)
		
		slot_item.slot_ = inventory_slots
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
	bag_closed.emit()  # 发送背包关闭信号
	
# ==================== 鼠标交互 ====================
func mouse_left_slot_button(slot_button):
	if slot_button.is_empty() and mouse_item:
		insert_item_in_slot(slot_button)
	elif not slot_button.is_empty() and not mouse_item:
		take_item_from_slot(slot_button)
	elif not slot_button.is_empty() and mouse_item:
		if slot_button.slot_button_slot_item.slot_.item.item_id != mouse_item.slot_.item.item_id:
			swap_items(slot_button)
		elif slot_button.slot_button_slot_item.slot_.item.max_stack == 1:
			swap_items(slot_button)
		else:
			stack_items(slot_button)

func mouse_right_slot_button(slot_button):
	if not slot_button.is_empty() and mouse_item:
		if slot_button.slot_button_slot_item.slot_.item.item_id != mouse_item.slot_.item.item_id:
			swap_items(slot_button)
		else:
			put_one_item_to_slot(slot_button)
	elif not slot_button.is_empty() and not mouse_item:
		take_half_items(slot_button)
	elif slot_button.is_empty() and mouse_item:
		put_one_item_to_slot(slot_button)

# ==================== 物品操作 ====================
func put_one_item_to_slot(slot_button):
	var success = slot_button.put_one_item(mouse_item.slot_)
	if success:
		if mouse_item.slot_.count <= 0:
			remove_child(mouse_item)
			mouse_item.queue_free()
			mouse_item = null
		else:
			mouse_item.slot_item_update()
		bag_inventory.inventory_update.emit()

func take_half_items(slot_button):
	if slot_button.slot_button_slot_item.slot_.count == 1:
		take_item_from_slot(slot_button)
		return
	
	var original_item: SlotItem = slot_button.slot_button_slot_item
	var original_count = original_item.slot_.count
	var take_count = ceil(original_count / 2.0)
	
	var new_item = slotitem_.instantiate()
	var new_slot = Slot.new()
	new_slot.item = original_item.slot_.item
	new_slot.count = take_count
	new_item.slot_ = new_slot
	
	original_item.slot_.count = original_count - take_count
	
	mouse_item = new_item
	add_child(mouse_item)
	item_follow_mouse()
	
	original_item.slot_item_update()
	mouse_item.slot_item_update()
	bag_inventory.inventory_update.emit()

func take_item_from_slot(slot_button):
	mouse_item = slot_button.take_item()
	if mouse_item:
		add_child(mouse_item)
		item_follow_mouse()

func item_follow_mouse():
	if not mouse_item:
		return
	mouse_item.global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	item_follow_mouse()

func insert_item_in_slot(slot_button):
	var item_ = mouse_item
	remove_child(mouse_item)
	mouse_item = null
	slot_button.insert(item_)

func swap_items(slot_button):
	var one_item = slot_button.take_item()
	insert_item_in_slot(slot_button)
	mouse_item = one_item
	add_child(mouse_item)
	item_follow_mouse()

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
	
	one_item.slot_item_update()
	if mouse_item:
		mouse_item.slot_item_update()
	bag_inventory.inventory_update.emit()
