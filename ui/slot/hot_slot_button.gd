extends Button

@onready var slot_background: ColorRect = $SlotBackGround
@onready var slot_item: SlotItem = $SlotBackGround/CenterContainer/SlotItem

func update_to_slot(hot_slot: Slot) -> void:
	#当前库存格子没有物品（快捷栏清空显示）
	if !hot_slot.item:
		slot_item.visible = false
		
		slot_background.color = Color(0.961, 0.945, 0.902, 0.0)
		return
	
	#当前库存格子有物品，给物品显示节点设置库存数据（关联物品类型和数量）
	slot_item.slot_ = hot_slot
	slot_item.slot_item_update()
	slot_item.visible = true
	
	slot_background.color = Color(0.961, 0.945, 0.902, 1.0)
