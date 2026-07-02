#// plant_data.gd
#// 作物数据资源，使用AtlasTexture手动定义裁剪区域，程序自动分割为4个生长阶段

extends Resource
class_name PlantData

#// ----- 基础属性 -----
@export var item_id: int = 0
@export var item_name: String = ""
@export var item_icon: Texture2D
@export var max_stack: int = 99
@export var description: String = ""

#// ----- 生长阶段贴图（使用AtlasTexture）-----
#// 在编辑器中，将AtlasTexture拖入此属性，并手动调整region区域
@export var growth_atlas: AtlasTexture :
	set(value):
		growth_atlas = value
		if growth_atlas:
			_split_atlas_into_stages()
		else:
			growth_stage_textures = []

#// 存储分割后的4个阶段贴图（索引0-3）
var growth_stage_textures: Array[Texture2D] = []

#// 分割AtlasTexture的核心方法
func _split_atlas_into_stages() -> void:
	if not growth_atlas:
		return
	
	#// 获取AtlasTexture的源纹理和裁剪区域
	var source_tex: Texture2D = growth_atlas.atlas
	if not source_tex:
		push_warning("PlantData: AtlasTexture没有指定源纹理(atlas)")
		return
	
	var region: Rect2 = growth_atlas.region
	#// 如果region未设置（默认空矩形），使用整个纹理
	if region == Rect2(0, 0, 0, 0):
		region = Rect2(0, 0, source_tex.get_width(), source_tex.get_height())
	
	#// 每个阶段的宽度 = 区域宽度 / 4
	var stage_width: float = region.size.x / 4.0
	var stage_height: float = region.size.y
	
	#// 如果区域宽度不足以分割4个阶段，发出警告
	if stage_width < 1.0:
		push_warning("PlantData: 裁剪区域宽度太小，无法分割为4个阶段")
		growth_stage_textures = []
		return
	
	growth_stage_textures.clear()
	
	#// 分割4个阶段
	for i in range(4):
		#// 计算当前阶段的子区域（在原始纹理中的坐标）
		var sub_region: Rect2 = Rect2(
			region.position.x + i * stage_width,
			region.position.y,
			stage_width,
			stage_height
		)
		#// 创建新的AtlasTexture作为阶段贴图
		var stage_atlas: AtlasTexture = AtlasTexture.new()
		stage_atlas.atlas = source_tex
		stage_atlas.region = sub_region
		#// 过滤模式与原AtlasTexture保持一致
		stage_atlas.filter_clip = growth_atlas.filter_clip
		growth_stage_textures.append(stage_atlas)

#// 获取指定生长阶段的贴图（索引0-3）
func get_stage_texture(stage: int) -> Texture2D:
	if stage >= 0 and stage < growth_stage_textures.size():
		return growth_stage_textures[stage]
	return null

#// 获取阶段总数（固定为4）
func get_stage_count() -> int:
	return 4

#// 在编辑器中显示阶段预览（可选）
func _get_property_list() -> Array:
	return []
