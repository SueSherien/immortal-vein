# time_manager.gd
# 全局时间管理器 - 控制游戏内时间流动
# 使用真实时间驱动，每秒推进游戏时间
extends Node

# ==================== 信号 ====================
signal time_changed              # 时间变化（任何单位）
signal hour_scroll_started(target_y)  # 时辰滚动开始
signal day_ended                 # 每天结束（寅时触发）

# ==================== 时间常量 ====================
const SECONDS_PER_STEP = 15.0    # 每刻现实时间（秒）
const STEPS_PER_HOUR = 8         # 每时辰刻数
const DAYS_PER_TERM = 4          # 每节气天数
const TERMS_PER_SEASON = 6       # 每季节节气数
const EXTRA_TERM = 1             # 额外节气（春节）
const TOTAL_TERMS = TERMS_PER_SEASON * 4 + EXTRA_TERM  # 总节气数 = 25

# ==================== 节气/时辰数据 ====================
# 节气名称（顺序：春6、夏6、秋6、冬6、春节）
var term_names = [
	"立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
	"立夏", "小满", "芒种", "夏至", "小暑", "大暑",
	"立秋", "处暑", "白露", "秋分", "寒露", "霜降",
	"立冬", "小雪", "大雪", "冬至", "小寒", "大寒",
	"春节"
]

# 时辰名称（12时辰，从卯时开始）
var hour_names = ["卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥", "子", "丑", "寅"]

# ==================== 当前时间状态 ====================
var year = 1                    # 当前年份
var solar_term_index = 0        # 当前节气索引 (0~24)
var day_in_term = 0             # 当前节气第几天 (0~3)
var hour_index = 0              # 当前时辰索引 (0~10, 卯~丑)
var step_index = 0              # 当前刻索引 (0~7)
var _time_accum = 0.0           # 时间累积器

# ==================== 生命周期 ====================
func _ready():
	emit_signal("time_changed")

func _process(delta):
	_time_accum += delta
	while _time_accum >= SECONDS_PER_STEP:
		_time_accum -= SECONDS_PER_STEP
		_advance_step()

# ==================== 核心逻辑 ====================
# 推进一个时间单位（1刻）
func _advance_step():
	step_index += 1
	
	if step_index >= STEPS_PER_HOUR:
		# 时辰结束，进入下一个时辰
		step_index = 0
		hour_index += 1
		
		if hour_index > 10:  # 到达寅时（一天结束）
			_end_day()
			return
		
		# 时辰变化，触发滚动动画
		var target_y = -hour_index * 21
		emit_signal("hour_scroll_started", target_y)
		emit_signal("time_changed")
	else:
		# 刻变化，只更新指针
		emit_signal("time_changed")

# 结束当前天，进入下一天
func _end_day():
	save_game()
	
	# 日期推进
	day_in_term += 1
	if day_in_term >= DAYS_PER_TERM:
		day_in_term = 0
		solar_term_index += 1
		if solar_term_index >= TOTAL_TERMS:
			solar_term_index = 0
			year += 1
	
	# 重置时辰为卯时
	hour_index = 0
	step_index = 0
	
	# 发送信号
	emit_signal("hour_scroll_started", 0)
	emit_signal("time_changed")
	emit_signal("day_ended")  # 触发农场生长更新

# ==================== 存档 ====================
func save_game():
	print("游戏已保存：第%d年，%s，第%d天" % [year, term_names[solar_term_index], day_in_term + 1])

# ==================== 调试功能 ====================
# 跳过4刻（半小时），用于测试
func skip_4_steps():
	for i in range(4):
		_advance_step()

# 快速跳到第二天，用于测试
func skip_to_next_day():
	_end_day()

# ==================== 辅助方法 ====================
func get_term_name() -> String:
	return term_names[solar_term_index]

func get_season_name() -> String:
	if solar_term_index < 6:
		return "春季"
	elif solar_term_index < 12:
		return "夏季"
	elif solar_term_index < 18:
		return "秋季"
	elif solar_term_index < 24:
		return "冬季"
	else:
		return "冬季"  # 春节归入冬季
