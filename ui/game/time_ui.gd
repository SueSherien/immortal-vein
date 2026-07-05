# time_ui.gd
# 时间显示UI - 显示时辰、节气、日期
extends Control

@onready var hour_container = $HourContainer
@onready var all_hours = $HourContainer/AllHours
@onready var dial_pointer = $DialPointer
@onready var date_label = $DateButton/Date
@onready var day_container = $Day

const HOUR_HEIGHT = 21  # 时辰图标高度

# ==================== 缓动动画 ====================
var current_y = 0.0
var target_y = 0.0
var is_animating = false
var animation_speed = 2.0

# ==================== 生命周期 ====================
func _ready():
	hour_container.clip_contents = true
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.hour_scroll_started.connect(_on_hour_scroll_started)
	_on_time_changed()

func _process(delta):
	if is_animating:
		var diff = target_y - current_y
		if abs(diff) < 0.01:
			current_y = target_y
			is_animating = false
		else:
			current_y += diff * (1.0 - exp(-animation_speed * delta))
		all_hours.position.y = current_y

# ==================== 信号处理 ====================
func _on_hour_scroll_started(target):
	target_y = target
	is_animating = true

func _on_time_changed():
	var tm = TimeManager
	var step = tm.step_index
	
	# 1. 时辰滚动（由缓动动画控制）
	if not is_animating:
		var idx = tm.hour_index
		current_y = -idx * HOUR_HEIGHT
		target_y = current_y
		all_hours.position.y = current_y
	
	# 2. 刻指针旋转（12点方向为第1刻）
	var angle = (step / float(TimeManager.STEPS_PER_HOUR)) * 360.0
	dial_pointer.rotation_degrees = angle
	
	# 3. 节气名称
	date_label.text = tm.get_term_name()
	
	# 4. 天数条（已过天数隐去对应方块）
	var day = tm.day_in_term
	for i in range(4):
		var rect = day_container.get_child(i)
		if rect is TextureRect:
			rect.visible = (i >= day)

# ==================== 调试 ====================
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		TimeManager.skip_4_steps()
