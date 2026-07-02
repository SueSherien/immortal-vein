extends Node

signal time_changed
signal hour_scroll_started(target_y)  # 新增：时辰滚动开始信号

# 时间常量
const SECONDS_PER_STEP = 15.0
const STEPS_PER_HOUR = 8
const DAYS_PER_TERM = 4
const TERMS_PER_SEASON = 6
const EXTRA_TERM = 1
const TOTAL_TERMS = TERMS_PER_SEASON * 4 + EXTRA_TERM  # 25

# 节气名称（顺序：春6、夏6、秋6、冬6、春节）
var term_names = [
	"立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
	"立夏", "小满", "芒种", "夏至", "小暑", "大暑",
	"立秋", "处暑", "白露", "秋分", "寒露", "霜降",
	"立冬", "小雪", "大雪", "冬至", "小寒", "大寒",
	"春节"
]
var hour_names = ["卯", "辰", "‌巳", "‌午", "‌未", "‌申","‌酉", "‌戌", "‌‌亥", "‌子", "‌丑", "‌寅"]

# 当前时间（初始：第1年春季第1节气第1天卯时）
var year = 1
var solar_term_index = 0      # 0~24
var day_in_term = 0           # 0~3
var hour_index = 0            # 0~10  (卯~丑)
var step_index = 0            # 0~7

var _time_accum = 0.0

func _ready():
	emit_signal("time_changed")

func _process(delta):
	_time_accum += delta
	while _time_accum >= SECONDS_PER_STEP:
		_time_accum -= SECONDS_PER_STEP
		_advance_step()

func _advance_step():
	step_index += 1
	if step_index >= STEPS_PER_HOUR:
		step_index = 0
		hour_index += 1
		if hour_index > 10:  # 到达寅时 → 结束当天
			_end_day()
			return
		# 当时辰变化时，先发出滚动信号，再更新时间信号
		var target_y = -hour_index * 21  # 21是时辰高度
		emit_signal("hour_scroll_started", target_y)
		emit_signal("time_changed")
	else:
		# 刻变化时只更新指针
		emit_signal("time_changed")

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
	# 重置滚动位置
	emit_signal("hour_scroll_started", 0)
	emit_signal("time_changed")

func save_game():
	print("游戏已保存：第%d年，%s，第%d天" % [year, term_names[solar_term_index], day_in_term + 1])

# 调试功能：跳过4刻（相当于半小时）
func skip_4_steps():
	for i in range(4):
		_advance_step()

# 辅助方法（供UI调用）
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
