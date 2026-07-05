# slot_button.gd
# 背包格子按钮 - 支持鼠标拖拽交互
extends Button

signal mouse_button_left_press
signal mouse_button_right_press

@onready var slot_background: ColorRect = $SlotBackGround
@onready var center_container: CenterContainer = $SlotBackGround/CenterContainer

var slot_inventory: Inventory
var slot_index: int
var slot_button_slot_item: SlotItem

# ==================== 初始化 ====================
func _ready():
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	reset_color()

func reset_color():
	slot_background.color = Color(0.961, 0.945, 0.902, 0.0)

# ==================== 物品插入 ====================
func insert(SI: SlotItem):
	slot_button_slot_item = SI
	slot_background.color = Color(0.961, 0.945, 0.902, 1.0)
	center_container.add_child(slot_button_slot_item)
	
	if not slot_button_slot_item.slot_:
		return
	slot_inventory.insert_slot(slot_index, slot_button_slot_item.slot_)

# ==================== 物品取出 ====================
func take_item():
	var take_item_ = slot_button_slot_item
	slot_inventory.remove_slot(slot_button_slot_item.slot_)
	
	if center_container.get_child_count() != 0:
		center_container.remove_child(slot_button_slot_item)
		slot_button_slot_item = null
	
	reset_color()
	return take_item_

func is_empty():
	return not slot_button_slot_item

# ==================== 物品操作 ====================
func put_one_item(mouse_slot: Slot) -> bool:
	if is_empty():
		var new_slot = Slot.new()
		new_slot.item = mouse_slot.item
		new_slot.count = 1
		
		var new_slot_item = preload("res://ui/slots/slot_item.tscn").instantiate()
		new_slot_item.slot_ = new_slot
		insert(new_slot_item)
		
		mouse_slot.count -= 1
		return true
	else:
		var existing_slot = slot_button_slot_item.slot_
		if existing_slot.item.item_id == mouse_slot.item.item_id:
			if existing_slot.count < existing_slot.item.max_stack:
				existing_slot.count += 1
				mouse_slot.count -= 1
				return true
	return false

func clear_slot():
	if slot_button_slot_item:
		center_container.remove_child(slot_button_slot_item)
		slot_button_slot_item = null
		reset_color()

# ==================== 输入处理 ====================
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			mouse_button_left_press.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			mouse_button_right_press.emit()
