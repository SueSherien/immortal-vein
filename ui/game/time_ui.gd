extends Control

@onready var hour_container = $HourContainer
@onready var all_hours = $HourContainer/AllHours
@onready var dial_pointer = $DialPointer
@onready var date_label = $DateButton/Date
@onready var day_container = $Day

const HOUR_HEIGHT = 21  # 时辰TextureRect的像素高度

# 缓动动画相关
var current_y = 0.0          # 当前实际y坐标
var target_y = 0.0           # 目标y坐标
var is_animating = false
var animation_speed = 2.0    # 缓动速度（可调，值越大越快）

func _ready():
	# 启用遮罩裁剪
	hour_container.clip_contents = true
	
	# 连接时间信号
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.hour_scroll_started.connect(_on_hour_scroll_started)
	
	# 初始刷新
	_on_time_changed()

func _process(delta):
	# 处理缓动动画
	if is_animating:
		# 使用指数缓动（Ease Out）
		var diff = target_y - current_y
		if abs(diff) < 0.01:
			current_y = target_y
			is_animating = false
		else:
			# 缓动公式：每次移动剩余距离的一部分
			current_y += diff * (1.0 - exp(-animation_speed * delta))
			# 或者使用更简单的线性插值：
			# current_y = lerp(current_y, target_y, animation_speed * delta)
		
		# 更新实际位置
		all_hours.position.y = current_y

func _input(event):
	# 调试按键：空格跳过4刻
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		TimeManager.skip_4_steps()

func _on_hour_scroll_started(target):
	target_y = target
	is_animating = true

func _on_time_changed():
	var tm = TimeManager
	var step = tm.step_index
	
	# ---- 1. 时辰滚动（由_process中的缓动动画控制） ----
	# 如果当前不在动画中，直接设置位置（处理初始化和其他情况）
	if not is_animating:
		# 确保位置在目标值
		var idx = tm.hour_index
		current_y = -idx * HOUR_HEIGHT
		target_y = current_y
		all_hours.position.y = current_y
	
	# ---- 2. 刻指针旋转（顺时针，12点方向为第1刻） ----
	var angle = (step / float(TimeManager.STEPS_PER_HOUR)) * 360.0
	dial_pointer.rotation_degrees = angle
	
	# ---- 3. 日期显示（仅节气名称） ----
	date_label.text = tm.get_term_name()
	
	# ---- 4. 天数条（当前节气已过天数，隐去对应方块） ----
	var day = tm.day_in_term
	for i in range(4):
		var rect = day_container.get_child(i)
		if rect is TextureRect:
			rect.visible = (i >= day)
