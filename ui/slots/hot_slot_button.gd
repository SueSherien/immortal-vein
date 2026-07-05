# hot_slot_button.gd
# 快捷栏格子按钮 - 显示单个快捷栏格子的物品
extends Button

@onready var slot_background: ColorRect = $SlotBackGround
@onready var slot_item: SlotItem = $SlotBackGround/CenterContainer/SlotItem

# 更新格子显示
func update_to_slot(hot_slot: Slot) -> void:
	if not hot_slot.item:
		slot_item.visible = false
		slot_background.color = Color(0.961, 0.945, 0.902, 0.0)
		return
	
	slot_item.slot_ = hot_slot
	slot_item.slot_item_update()
	slot_item.visible = true
	slot_background.color = Color(0.961, 0.945, 0.902, 1.0)
