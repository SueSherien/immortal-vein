# slot_item.gd
# 格子物品显示 - 显示物品图标和数量
extends Control
class_name SlotItem

@onready var item_texture: TextureRect = $ItemTexture
@onready var amount_label: Label = $AmountLabel

var slot_: Slot

# 更新物品显示
func slot_item_update():
	if not slot_ or not slot_.item:
		return
	
	item_texture.visible = true
	item_texture.texture = slot_.item.item_texture
	
	if slot_.count > 1:
		amount_label.visible = true
		amount_label.text = str(slot_.count)
	else:
		amount_label.visible = false
