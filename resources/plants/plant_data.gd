# ============================================================================
# plant_data.gd
# 作物数据资源 - 定义作物的生长参数、贴图和显示偏移
# 继承自 Resource，可以在文件系统中创建为 .tres 资源文件
# ============================================================================
extends Resource
class_name PlantData

# ==================== 生长贴图 ====================
# AtlasTexture 包含4个阶段的贴图（水平排列）
# 阶段0: 发芽, 阶段1: 生长, 阶段2: 即将成熟, 阶段3: 成熟
@export var growth_atlas: AtlasTexture:
	set(value):
		growth_atlas = value
		if growth_atlas:
			_split_atlas_into_stages()
		else:
			growth_stage_textures = []

# 分割后的4个阶段贴图数组，由 _split_atlas_into_stages() 自动填充
var growth_stage_textures: Array[Texture2D] = []

# ==================== 生长参数 ====================
@export var growth_days: int = 4           # 需要多少天成熟
@export var growth_multiplier: int = 1     # 生长速度倍率（预留，暂未使用）
@export var harvest_type: int = 0          # 0=一年生（收获后消失）, 1=多年生（收获后重生）
@export var regrowth_days: int = 3         # 多年生再次成熟所需天数（预留）
@export var season_restriction: String = "" # 季节限制（空=不限，预留）

# ==================== 收获产物 ====================
@export var harvest_item: ItemData         # 收获后得到的物品资源
@export var harvest_count: int = 1         # 每次收获数量（预留）

# ==================== 枯萎贴图 ====================
@export var withered_texture: Texture2D    # 多年生过季时的枯萎贴图

# ==================== 显示偏移 ====================
# Y轴偏移量（像素），用于调整作物精灵在地图格中的垂直位置
# 正值向下移动，负值向上移动
# 不同作物因外观不同，需要不同的偏移值来对齐地图格
# 例如：胡萝卜需要负值（偏上），萝卜需要正值（偏下）
@export var y_offset: int = 0:
	set(value):
		y_offset = value
		# 注意：这里不自动刷新纹理，因为纹理不包含偏移信息
		# 偏移是在 farm_manager 中应用到 Sprite 的 position

# ==================== Atlas 分割方法 ====================
# 将水平排列的 AtlasTexture 分割为4个阶段
# 注意：分割时不应用 y_offset，保持纹理原始状态
# y_offset 将在 farm_manager 中应用到 Sprite 节点
func _split_atlas_into_stages() -> void:
	if not growth_atlas:
		return
	
	var source_tex: Texture2D = growth_atlas.atlas
	if not source_tex:
		push_warning("PlantData: AtlasTexture没有指定源纹理")
		return
	
	# 获取裁剪区域
	var region: Rect2 = growth_atlas.region
	if region == Rect2(0, 0, 0, 0):
		region = Rect2(0, 0, source_tex.get_width(), source_tex.get_height())
	
	# 计算每个阶段的宽度（4等分）
	var stage_width: float = region.size.x / 4.0
	var stage_height: float = region.size.y
	
	if stage_width < 1.0:
		push_warning("PlantData: 裁剪区域宽度太小，无法分割为4个阶段")
		growth_stage_textures = []
		return
	
	growth_stage_textures.clear()
	
	# 分割4个阶段
	for i in range(4):
		# 计算每个子区域的矩形
		# 注意：这里不应用 y_offset，保持纹理原始位置
		var sub_region: Rect2 = Rect2(
			region.position.x + i * stage_width,  # X轴：水平分割
			region.position.y,                     # Y轴：保持原始位置
			stage_width,
			stage_height
		)
		
		# 创建新的 AtlasTexture 引用源纹理的特定区域
		var stage_atlas: AtlasTexture = AtlasTexture.new()
		stage_atlas.atlas = source_tex
		stage_atlas.region = sub_region
		stage_atlas.filter_clip = growth_atlas.filter_clip
		growth_stage_textures.append(stage_atlas)

# ==================== 查询方法 ====================
# 获取指定生长阶段的贴图
# 参数: stage - 阶段索引 (0~3)
# 返回: Texture2D - 对应阶段的贴图，无效则返回 null
func get_stage_texture(stage: int) -> Texture2D:
	if stage >= 0 and stage < growth_stage_textures.size():
		return growth_stage_textures[stage]
	return null

# 获取生长阶段总数（固定为4）
func get_stage_count() -> int:
	return 4

# ==================== 工具方法 ====================
# 检查资源是否完整可用
func is_valid() -> bool:
	return not growth_stage_textures.is_empty() and harvest_item != null
