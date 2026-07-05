# hot_bar_ui.gd
# 快捷栏UI - 显示快捷栏物品，支持数字键切换
extends Control

@onready var hot_bar_inventory: Inventory
@onready var hot_bar_slots: Array = $PanelContainer/MarginContainer/HBoxContainer.get_children()
@onready var selector: TextureRect = $Selector

var selected_index: int = 0

# ==================== 初始化 ====================
func hot_bar_ready():
	hot_bar_update()
	hot_bar_inventory.inventory_update.connect(hot_bar_update)

func hot_bar_update():
	for i in range(hot_bar_slots.size()):
		var inventory_slot: Slot = hot_bar_inventory.slots[i]
		hot_bar_slots[i].update_to_slot(inventory_slot)

# ==================== 选择切换 ====================
signal selector_moved(new_index)   # 快捷栏选择变化
func move_selector(new_selector_index: int):
	if new_selector_index < 0 or new_selector_index >= hot_bar_slots.size():
		return
	selected_index = new_selector_index
	selector.global_position = hot_bar_slots[selected_index].global_position + Vector2(-5, -5)
	
	if new_selector_index < 0 or new_selector_index >= hot_bar_slots.size():
		return
	selected_index = new_selector_index
	selector.global_position = hot_bar_slots[selected_index].global_position + Vector2(-5, -5)
	selector_moved.emit(selected_index)   # 发送信号
	
# ==================== 输入处理 ====================
func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		hot_bar_inventory.use_item(selected_index)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hot_bar_inventory.use_tool(selected_index)
# hot_bar_ui.gd（新增信号）
