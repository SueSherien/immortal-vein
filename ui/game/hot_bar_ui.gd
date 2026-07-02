extends Control

#关联玩家库存，后续由玩家脚本赋值
@onready var hot_bar_inventory: Inventory
#获取所有hot_bar_slot格子节点
@onready var hot_bar_slots: Array =\
$PanelContainer/MarginContainer/HBoxContainer.get_children()
@onready var selector: TextureRect = $Selector

var selected_index: int = 0

func hot_bar_ready() -> void:
	hot_bar_update()
	#连接库存更新信号，当背包库存变动时自动调用update函数，同步显示快捷栏
	hot_bar_inventory.inventory_update.connect(hot_bar_update)
	
#批量更新所有快捷栏格子，与背包快捷栏同步
func hot_bar_update() -> void:
	#循环遍历所有快捷栏格子
		for i in range(hot_bar_slots.size()):
		#获取第i个格子
			var inventory_slot: Slot = hot_bar_inventory.slots[i]
			hot_bar_slots[i].update_to_slot(inventory_slot)

#鼠标输入处理函数
func _input(event: InputEvent) -> void:
	#只有快捷栏显示时才生效
	if visible:
		#监听鼠标右键，点击右键时触发物品使用
		if event is InputEventMouseButton and\
		event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			hot_bar_inventory.use_item(selected_index)
		#监听鼠标左键，点击左键时触发工具使用
		if event is InputEventMouseButton and\
		event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			hot_bar_inventory.use_tool(selected_index)
			
		switch_item()
		
		
#快捷键切换
func switch_item():
	#监听1-0数字键，切换快捷栏物品选择
	for i in range(min(10, hot_bar_slots.size())):
		if Input.is_action_just_pressed("hot_bar" + str(i)):
			#调用移动选择函数
			move_selector(i)

#更新选中索引，移动选择框UI到对应格子上
func move_selector(new_selector_index: int):
	selected_index = new_selector_index
	selector.global_position = (hot_bar_slots[selected_index].global_position + Vector2(-5, -5))
	
	
