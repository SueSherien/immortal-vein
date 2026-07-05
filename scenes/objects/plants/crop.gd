# Crop.gd
extends Node2D

@onready var sprite: Sprite2D = $Sprite

# 存储作物数据引用
var grid_position: Vector2i
var crop_data: FarmManager.CropData

func _ready():
	# 可添加动画或交互效果
	pass

# 更新作物贴图
func update_texture(new_texture: Texture2D):
	if sprite:
		sprite.texture = new_texture

# 获取世界坐标对应的格子位置（由FarmManager设置）
func set_grid_position(pos: Vector2i):
	grid_position = pos
