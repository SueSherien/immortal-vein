extends Control

class_name SlotItem

@onready var item_texture: TextureRect = $ItemTexture
@onready var amount_label: Label = $AmountLabel

#定义变量：存储当前物品对应的库存格子数据
var slot_: Slot

#物品显示更新函数（用来同步库存数据到图标和数量）
func slot_item_update():
	#如果没有库存格子数据或者库存格子里没有品，直接返回避免报错
	if !slot_ or !slot_.item: return
	
	#有物品时显示物品图标，图标等于库存物品的图标
	item_texture.visible = true
	item_texture.texture = slot_.item.item_texture
	
	if slot_.count > 1:
		amount_label.visible = true
		amount_label.text = str(slot_.count)
		
	else :
		amount_label.visible = false
	
	
