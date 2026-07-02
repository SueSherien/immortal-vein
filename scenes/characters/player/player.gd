class_name Player
extends CharacterBody2D

@onready var bag_ui: Control = $GameUI/CanvasLayer/BagUI
@onready var hot_bar_ui: Control = $GameUI/CanvasLayer/HotBarUI

#玩家专属库存变量
@export var player_inventory: Inventory

#检测背包是否处于打开状态
var is_bag_open: bool = false

func _ready():
	## 初始化UI：设置库存数据并同步到UI，背包默认隐藏
	#bag_ui.bag_inventory = player_inventory
	#bag_ui.bag_update()
	hot_bar_ui.hot_bar_inventory = player_inventory
	hot_bar_ui.hot_bar_ready()
	
	
func _input(event):
	if event.is_action_pressed("toggle_bag"):
		toggle_bag()

#背包状态切换 - 仅控制背包栏
func toggle_bag():
	if is_bag_open == true:
		bag_ui.close_bag()
		is_bag_open = false
		hot_bar_ui.visible = true
		
	elif is_bag_open == false:
		bag_ui.open_bag(player_inventory)
		is_bag_open = true
		hot_bar_ui.visible = false
		
#玩家移动操作相关
var speed : int = 150
var move_direction: Vector2 = Vector2(0,0)

func _physics_process(_delta: float) -> void:
	movement_loop()

func movement_loop() ->void:
	move_direction.x = int(Input.is_action_pressed("walk_right")) - int(Input.is_action_pressed("walk_left"))
	move_direction.y = (int(Input.is_action_pressed("walk_down")) - int(Input.is_action_pressed("walk_up"))) / float(2)
	var motion: Vector2 = move_direction.normalized() * speed
	set_velocity(motion)
	move_and_slide()
