@tool
extends EditorPlugin

var target_container: War3TileMapLayer = null

# UI
var editor_dock: EditorDock = null
var dock_content: VBoxContainer = null
var btn_create_sub_layers : Button = null
var btn_refresh_tileset : Button = null
var terrain_tree: Tree = null
var brush_slider: EditorSpinSlider = null


func _enter_tree() -> void:
	create_dock_panel()
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	if editor_dock:
		remove_dock(editor_dock)
		editor_dock.queue_free()
		editor_dock = null

	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)


func _on_selection_changed():
	var selected = EditorInterface.get_selection().get_selected_nodes()
	btn_create_sub_layers.disabled = true
	if selected.is_empty():
		target_container = null
		return
	
	var node = selected[0]
	if node is War3TileMapLayer:
		target_container = node 
		_on_btn_refresh_tileset()
		if editor_dock:
			editor_dock.make_visible()
		if !target_container.has_all_corner_layers():
			btn_create_sub_layers.disabled = false


func create_dock_panel():
	if editor_dock != null:
		return

	editor_dock = EditorDock.new()
	editor_dock.title = "War3地形编辑器"
	editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM

	dock_content = VBoxContainer.new()
	dock_content.custom_minimum_size = Vector2(0,100)

	var hbox_top = HBoxContainer.new()
	dock_content.add_child(hbox_top)

	btn_create_sub_layers = Button.new()
	btn_create_sub_layers.text = "创建画布"
	btn_create_sub_layers.disabled = true
	btn_create_sub_layers.pressed.connect(_on_btn_create_subs)
	hbox_top.add_child(btn_create_sub_layers)	

	var label = Label.new()
	label.text = "笔刷半径:"
	hbox_top.add_child(label)

	brush_slider = EditorSpinSlider.new()
	brush_slider.min_value = 1.0
	brush_slider.max_value = 10.0
	brush_slider.step = 1.0
	brush_slider.custom_minimum_size.x = 200
	hbox_top.add_child(brush_slider)

	btn_refresh_tileset = Button.new()
	btn_refresh_tileset.text = "刷新"
	btn_refresh_tileset.pressed.connect(_on_btn_refresh_tileset)
	hbox_top.add_child(btn_refresh_tileset)

	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_content.add_child(split)

	var vbox_c = VBoxContainer.new()
	vbox_c.custom_minimum_size = Vector2(300,0)
	vbox_c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	terrain_tree = Tree.new()
	terrain_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	terrain_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_tree.columns = 1
	terrain_tree.select_mode = Tree.SELECT_ROW
	vbox_c.add_child(terrain_tree)

	split.add_child(vbox_c)
	split.add_child(Panel.new())

	editor_dock.add_child(dock_content)
	add_dock(editor_dock)


func _on_btn_create_subs():
	target_container.build_all_layers()
	btn_create_sub_layers.disabled = true

func _on_btn_refresh_tileset():
	if !target_container:
		return
	#更新子节点tileset
	target_container.set_sublayers_tileset(target_container.tile_set)
	#更新控件树
	refresh_terrain_tree()

#刷新地形树
func refresh_terrain_tree():
	terrain_tree.clear()
	var root = terrain_tree.create_item()
	root.set_text(0, "TileSet地形列表")
	root.set_selectable(0, false)
	if !target_container || !target_container.tile_set:
		return
	var tile_set = target_container.tile_set
	var set_count = tile_set.get_terrain_sets_count()
	if set_count == 0:
		return

	for set_idx in range(set_count):
		var mode_str : String
		match tile_set.get_terrain_set_mode(set_idx):
			TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: mode_str="匹配边+角"
			TileSet.TERRAIN_MODE_MATCH_CORNERS: mode_str="仅匹配角"
			TileSet.TERRAIN_MODE_MATCH_SIDES: mode_str="仅匹配边"
			_: "未知模式"
		var terrain_cnt = tile_set.get_terrains_count(set_idx)
		var set_item = terrain_tree.create_item(root)
		set_item.set_text(0, "地形集%d [%s] 共%d个" % [set_idx, mode_str, terrain_cnt])
		set_item.set_selectable(0, false)
		if terrain_cnt == 0:
			var empty = terrain_tree.create_item(set_item)
			empty.set_text(0, "无地形")
			empty.set_selectable(0, false)
			continue
		for tid in range(terrain_cnt):
			var name = tile_set.get_terrain_name(set_idx, tid)
			if name.is_empty():
				name = "地形%d" % tid
			var item = terrain_tree.create_item(set_item)
			item.set_text(0, name)
			item.set_metadata(0, {"set": set_idx, "terrain": tid})
			var icon = get_terrain_icon(tile_set, set_idx, tid)
			if icon:
				item.set_icon(0, icon)

# 获取地形缩略图
func get_terrain_icon(tile_set: TileSet, set_idx: int, terrain_id: int) -> Texture2D:
	for src_idx in range(tile_set.get_source_count()):
		var src_id = tile_set.get_source_id(src_idx)
		var source = tile_set.get_source(src_id)
		if !(source is TileSetAtlasSource):
			continue
		var atlas = source as TileSetAtlasSource
		var tex = atlas.texture
		if !tex:
			continue
		var grid_size = atlas.get_atlas_grid_size()
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var grid_pos = Vector2i(x, y)
				var tile_coords = atlas.get_tile_at_coords(grid_pos)
				if tile_coords.x == -1:
					continue
				var tile_data = atlas.get_tile_data(tile_coords, 0)
				if tile_data && tile_data.get_terrain_set() == set_idx && tile_data.get_terrain() == terrain_id:
					var reg = atlas.get_tile_texture_region(tile_coords, 0)
					var atlas_tex = AtlasTexture.new()
					atlas_tex.atlas = tex
					atlas_tex.region = reg
					return atlas_tex
	return null

# 获取选中地形信息，返回字典
func get_selected_terrain_info() -> Dictionary:
	var selected_item = terrain_tree.get_selected()
	if not selected_item:
		return {}
	var meta = selected_item.get_metadata(0)
	# 校验元数据结构，避免点选父节点报错
	if meta is Dictionary and meta.has("set") and meta.has("terrain"):
		return meta
	return {}

# 网格邻域角映射
const CELL_MAP_SQUARE: Array[int] = [0, 1, 2, 3]
const CELL_MAP_ISO: Array[int] = [2, 3, 0, 1]
# 方格顶点四向邻点（上下左右）
const SQUARE_VERTEX_NEIGHBORS = [
	Vector2i(1,0),
	Vector2i(-1,0),
	Vector2i(0,1),
	Vector2i(0,-1),
]
# 方格顶点对应4个相交瓦片偏移
const SQUARE_VTX_TO_CELL_OFF = [
	Vector2i(0, 0),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
]
# 等距瓦片邻接索引映射
const OFFSET_EVEN = {
		0: [Vector2i(0,0), Vector2i(-1,-1), Vector2i(0,-2), Vector2i(0,-1)],
		1: [Vector2i(0,0), Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1)],
		2: [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2), Vector2i(-1,1)],
		3: [Vector2i(0,0), Vector2i(-1,-1), Vector2i(-1,0), Vector2i(-1,1)]
	}
const OFFSET_ODD = {
	0: [Vector2i(0,0), Vector2i(0,-1), Vector2i(0,-2), Vector2i(1,-1)],
	1: [Vector2i(0,0), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1)],
	2: [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2), Vector2i(1,1)],
	3: [Vector2i(0,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
}
# 鼠标交互状态
var is_left_dragging: bool = false
var is_right_dragging: bool = false
# 当前命中瓦片角下标
var current_hit_corner_idx: int = 0
# 当前命中的瓦片
var current_hit_tile : Vector2i = Vector2i.ZERO
#当前受影响的瓦片坐标集
var hover_cells: Array[Vector2i] = []
# 撤销快照
var initial_data: Array = []
var has_modified: bool = false

# 地形掩码数据类：存储单瓦片四角地形ID
class TerrainMask:
	var tl: int = -1
	var tr: int = -1
	var br: int = -1
	var bl: int = -1

	func _init(p_tl: int = -1, p_tr: int = -1, p_br: int = -1, p_bl: int = -1):
		tl = p_tl
		tr = p_tr
		br = p_br
		bl = p_bl

	func equals(other: TerrainMask) -> bool:
		return tl == other.tl && tr == other.tr && br == other.br && bl == other.bl
	
	# 新增：打印自动调用
	func _to_string() -> String:
		return "TerrainMask(tl=%d, tr=%d, br=%d, bl=%d)" % [tl, tr, br, bl]

	# 根据角下标赋值地形
	func set_corner(idx: int, value: int):
		match idx:
			0: tl = value
			1: tr = value
			2: br = value
			3: bl = value

	# 获取指定角地形ID
	func get_corner(idx: int) -> int:
		match idx:
			0: return tl
			1: return tr
			2: return br
			3: return bl
			_: return -1

	# 提取当前瓦片所有地形+对应角位bit掩码
	func get_terrain_masks() -> Dictionary[int, int]:
		var res: Dictionary[int, int] = {}
		var corners: Array[int] = [tl, tr, br, bl]
		for idx in range(4):
			var tid = corners[idx]
			if tid == -1:
				continue
			if !res.has(tid):
				res[tid] = 0
			res[tid] |= 1 << idx
		return res

# 获取TileSet对应四角邻域枚举
func _get_corner_dirs(shape: TileSet.TileShape) -> Array[int]:
	match shape:
		TileSet.TILE_SHAPE_SQUARE:
			return [
				TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
			]
		TileSet.TILE_SHAPE_ISOMETRIC:
			return [
				TileSet.CELL_NEIGHBOR_LEFT_CORNER,
				TileSet.CELL_NEIGHBOR_TOP_CORNER,
				TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
				TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
			]
	return []

# 输入：瓦片网格坐标 tile_map_pos(Vector2i)
# 输出：center(瓦片中心) + corners[4] = 4个网格交叉角（地形混合四角，匹配War3角点）
func calc_tile_local_corners(tile_map_pos: Vector2i, tileset: TileSet) -> Dictionary:
	var cell_size: Vector2 = tileset.tile_size
	var shape = tileset.tile_shape
	var sample_layer = target_container.get_corner_layers()[0]
	# 1. 引擎标准map_to_local原点（瓦片贴图左上角基准点）
	var tile_origin = sample_layer.map_to_local(tile_map_pos)
	var half_x = cell_size.x * 0.5
	var half_y = cell_size.y * 0.5
	var corners: Array[Vector2] = []

	if shape == TileSet.TILE_SHAPE_SQUARE:
		corners = [
			tile_origin + Vector2(-half_x, -half_y),			
			tile_origin + Vector2(half_x, -half_y),
			tile_origin + Vector2(half_x, half_y),
			tile_origin + Vector2(-half_x, half_y),
		]
	elif shape == TileSet.TILE_SHAPE_ISOMETRIC:
		corners = [
			tile_origin + Vector2(-half_x, 0),
			tile_origin + Vector2(0, -half_y),
			tile_origin + Vector2(half_x, 0),
			tile_origin + Vector2(0, half_y)
		]
	return {
		"center": tile_origin,
		"corners": corners,
	}

# GUI鼠标坐标(EditorViewport控件本地) → TileMapLayer局部坐标
func gui_mouse_to_tile_local(gui_mouse: Vector2) -> Vector2:
	if !target_container or !is_instance_valid(target_container):
		return Vector2.ZERO
	var vp_root = EditorInterface.get_editor_viewport_2d()
	var canvas_xform: Transform2D = vp_root.global_canvas_transform
	var canvas_world = canvas_xform.affine_inverse() * gui_mouse
	return target_container.to_local(canvas_world)

# TileMapLayer局部坐标 → EditorViewport控件GUI绘图坐标（供draw_line/draw_circle使用）
func tile_local_to_gui(local_pt: Vector2) -> Vector2:
	if !target_container or !is_instance_valid(target_container):
		return Vector2.ZERO
	var vp_root = EditorInterface.get_editor_viewport_2d()
	var canvas_xform: Transform2D = vp_root.global_canvas_transform
	var canvas_world = target_container.to_global(local_pt)
	return canvas_xform * canvas_world

# 根据控件鼠标坐标，返回当前瓦片命中角下标
func get_hit_corner(gui_mouse: Vector2) -> int:
	if !target_container || !target_container.tile_set:
		return 0
	var tile_set = target_container.tile_set
	var sample_layer = target_container.get_corner_layers()[0]
	var local_pos = gui_mouse_to_tile_local(gui_mouse)
	var tile_pos = sample_layer.local_to_map(local_pos)
	
	var tile_info = calc_tile_local_corners(tile_pos, tile_set)
	#print("Local_pos: ", local_pos, "Tile: ", tile_pos, "Center: ", tile_info.center, " Corners: ", tile_info.corners)
	var min_dist_sq = INF
	var hit_idx = 0
	for i in range(4):
		var dist_sq = (local_pos - tile_info.corners[i]).length_squared()
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			hit_idx = i
	return hit_idx

# 获取单个瓦片本地坐标系顶点数组（绘制边框）
func get_tile_local_verts(cell_map_pos: Vector2i, tileset: TileSet) -> PackedVector2Array:
	var tile_info = calc_tile_local_corners(cell_map_pos, tileset)
	if !tile_info.has("corners"):
		return PackedVector2Array()
	var corners = tile_info.corners
	var arr = PackedVector2Array()
	for p in corners:
		arr.append(p)
	return arr

# 获取指定瓦片当前四角地形掩码
func get_cell_mask(cell: Vector2i) -> TerrainMask:
	if !target_container || !target_container.tile_set:
		return TerrainMask.new()
	var layers = target_container.get_corner_layers()
	if layers.size() != 4:
		return TerrainMask.new()
	var tile_set = target_container.tile_set
	var corner_dirs = _get_corner_dirs(tile_set.tile_shape)
	var mask = TerrainMask.new()

	for layer_idx in range(4):
		var layer = layers[layer_idx]
		if !is_instance_valid(layer):
			continue
		var src_id = layer.get_cell_source_id(cell)
		if src_id == -1:
			continue
		var tile_data = layer.get_cell_tile_data(cell)
		if !tile_data:
			continue
		var terrain_id = tile_data.get_terrain()
		if terrain_id == -1:
			continue
		for i in range(4):
			if tile_data.get_terrain_peering_bit(corner_dirs[i]) == terrain_id:
				mask.set_corner(i, terrain_id)
	return mask

#BFS 返回：顶点Vector2i => [[cell, corner_idx], ...] 完整映射
func _brush_vertex_bfs(p_tile_pos: Vector2i, p_corner_pos: int, brush_size: int) -> Dictionary:
	if not target_container or not target_container.tile_set:
		return {}
	var tile_set = target_container.tile_set
	var shape = tile_set.tile_shape
	var cell_size = Vector2(tile_set.tile_size)
	var tw = cell_size.x
	var th = cell_size.y
	var tile_info = calc_tile_local_corners(p_tile_pos, tile_set)
	var origin_corner_px = tile_info.corners[p_corner_pos]
	var layers = target_container.get_corner_layers()
	if layers.is_empty():
		return {}
	var sample_layer = layers[0]

	var vertex_cell_map:Dictionary = {}

	match shape:
		TileSet.TILE_SHAPE_ISOMETRIC:
			var half_x = tw / 2.0
			var half_y = th / 2.0
			var corner_offsets = [
				Vector2(0, -half_y),
				Vector2(half_x, 0),
				Vector2(0, half_y),
				Vector2(-half_x, 0)
			]

			var max_distance = brush_size - 1
			var vertex_neigh_disp = [
				Vector2i(1,1),
				Vector2i(1,-1),
				Vector2i(-1,1),
				Vector2i(-1,-1)
			]
			var vx_start = round(origin_corner_px.x / (tw * 0.5))
			var vy_start = round(origin_corner_px.y / (th * 0.5))
			var start_v = Vector2i(vx_start, vy_start)

			var vertex_dist:Dictionary = {}
			var seed_vertices:Array[Vector2i] = [start_v]
			var start_key = str(start_v.x)+","+str(start_v.y)
			vertex_dist[start_key] = 0

			while seed_vertices.size() > 0:
				var next_seed:Array[Vector2i] = []
				for v in seed_vertices:
					var v_key = str(v.x)+","+str(v.y)
					var dist = vertex_dist[v_key]

					if dist <= max_distance:
						var cr_px_x = v.x * tw * 0.5
						var cr_px_y = v.y * th * 0.5
						var cr_px = Vector2(cr_px_x, cr_px_y)
						var map_pos = sample_layer.local_to_map(cr_px)
						var tile_center_local = sample_layer.map_to_local(map_pos)

						var nearest_idx = 0
						var min_d_sq = INF
						for i in range(4):
							var vp = tile_center_local + corner_offsets[i]
							var dsq = (cr_px - vp).length_squared()
							if dsq < min_d_sq:
								min_d_sq = dsq
								nearest_idx = i

						var is_even = (map_pos.y % 2 == 0)
						var cell_offsets = OFFSET_EVEN[nearest_idx] if is_even else OFFSET_ODD[nearest_idx]

						var cell_list:Array[Vector2i] = []
						for off in cell_offsets:
							cell_list.append(map_pos + off)

						var cell_corner_pairs:Array = []
						for i in range(4):
							var cell = cell_list[i]
							var cor_idx = CELL_MAP_ISO[i]
							cell_corner_pairs.append([cell, cor_idx])
						vertex_cell_map[v] = cell_corner_pairs

					if dist < max_distance:
						for disp in vertex_neigh_disp:
							var nv = v + disp
							var nk = str(nv.x)+","+str(nv.y)
							if not vertex_dist.has(nk):
								vertex_dist[nk] = dist + 1
								next_seed.append(nv)
				seed_vertices = next_seed
		TileSet.TILE_SHAPE_SQUARE:
			var max_distance = brush_size - 1
			var half_unit = tw * 0.5
			var vx_start = round(origin_corner_px.x / half_unit)
			var vy_start = round(origin_corner_px.y / half_unit)
			var start_v = Vector2i(vx_start, vy_start)

			# 计算全局坐标偏移修正量
			var start_cr_px_x = start_v.x * half_unit
			var start_cr_px_y = start_v.y * half_unit
			var start_cr_px = Vector2(start_cr_px_x, start_cr_px_y)
			var start_map_pos = sample_layer.local_to_map(start_cr_px)
			var offset_fix = start_map_pos - start_v

			var vertex_dist:Dictionary = {}
			var seed_vertices:Array[Vector2i] = [start_v]
			var start_key = str(start_v.x)+","+str(start_v.y)
			vertex_dist[start_key] = 0

			while seed_vertices.size() > 0:
				var next_seed:Array[Vector2i] = []
				for v in seed_vertices:
					var v_key = str(v.x)+","+str(v.y)
					var dist = vertex_dist[v_key]

					if dist <= max_distance:
						var cr_px_x = v.x * half_unit
						var cr_px_y = v.y * half_unit
						var cr_px = Vector2(cr_px_x, cr_px_y)
						var map_pos = sample_layer.local_to_map(cr_px)
						var tile_cor_data = calc_tile_local_corners(map_pos, tile_set)
						var tile_corners = tile_cor_data.corners

						var hit_cor = 0
						var min_d_sq = INF
						for i in range(4):
							var dsq = (cr_px - tile_corners[i]).length_squared()
							if dsq < min_d_sq:
								min_d_sq = dsq
								hit_cor = i

						var cell_list:Array[Vector2i] = [
							Vector2i(v.x, v.y),
							Vector2i(v.x - 1, v.y),
							Vector2i(v.x - 1, v.y - 1),
							Vector2i(v.x, v.y - 1),
						]
						for i in range(cell_list.size()):
							cell_list[i] += offset_fix
							
						var cell_corner_pairs:Array = []
						for i in range(4):
							var cell = cell_list[i]
							var cor_idx = CELL_MAP_SQUARE[i]
							cell_corner_pairs.append([cell, cor_idx])
						vertex_cell_map[v] = cell_corner_pairs

					# 4邻顶点扩散保证斜向顶点全部遍历
					if dist < max_distance:
						for disp in SQUARE_VERTEX_NEIGHBORS:
							var nv = v + disp
							var nk = str(nv.x)+","+str(nv.y)
							if not vertex_dist.has(nk):
								vertex_dist[nk] = dist + 1
								next_seed.append(nv)
				seed_vertices = next_seed
	return vertex_cell_map

#获取笔刷影响的角点
func get_brush_affected_vertices(p_tile_pos: Vector2i, p_corner_pos: int, brush_size: int) -> Dictionary:
	return _brush_vertex_bfs(p_tile_pos, p_corner_pos, brush_size)
#获取笔刷影响的格子
func get_brush_affected_cells(p_tile_pos: Vector2i, p_corner_pos: int, brush_size: int) -> Array[Vector2i]:
	var vertex_map = _brush_vertex_bfs(p_tile_pos, p_corner_pos, brush_size)
	var cell_set: Dictionary[Vector2i, bool] = {}
	# 遍历所有顶点关联的格子，自动去重
	for vert in vertex_map:
		for pair in vertex_map[vert]:
			var cell = pair[0]
			cell_set[cell] = true
	# 转数组返回
	return cell_set.keys()

# 根据掩码匹配对应瓦片坐标（地形混合核心） 
func find_tile_by_mask_probability(tile_set: TileSet, source_id: int, set_idx: int, terrain_id: int, mask: int) -> Variant:
	var source = tile_set.get_source(source_id)
	if !(source is TileSetAtlasSource):
		return null
	var atlas = source as TileSetAtlasSource
	var corner_dirs = _get_corner_dirs(tile_set.tile_shape)
	var grid_size = atlas.get_atlas_grid_size()
	
	var candidates = []  # 存储 { coords: Vector2i, weight: float }
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var grid_pos = Vector2i(x, y)
			var coords = atlas.get_tile_at_coords(grid_pos)
			if coords.x == -1:
				continue
			var tile_data = atlas.get_tile_data(coords, 0)
			if !tile_data || tile_data.get_terrain_set() != set_idx:
				continue
			
			# 构建当前图块的掩码
			var tile_mask = 1 << 4
			for i in range(4):
				if tile_data.get_terrain_peering_bit(corner_dirs[i]) == terrain_id:
					tile_mask |= 1 << i
			
			if tile_mask == mask:
				# 直接使用官方 probability 属性
				var weight = tile_data.probability
				if weight > 0:
					candidates.append({ "coords": coords, "weight": weight })
	
	if candidates.is_empty():
		return null
	
	# 计算总权重
	var total_weight = 0.0
	for c in candidates:
		total_weight += c.weight
	
	# 按权重随机选择
	var r = randf() * total_weight
	var accumulated = 0.0
	for c in candidates:
		accumulated += c.weight
		if r <= accumulated:
			return c.coords
	
	return null

# 批量同步瓦片图层显示
func sync_cell_display(cells: Array, masks: Dictionary):
	if !target_container || !target_container.tile_set:
		return
	var layers = target_container.get_corner_layers()
	if layers.size() != 4:
		return
	var tile_set = target_container.tile_set
	var unique_cells = cells.duplicate()

	var terrain_info = get_selected_terrain_info()
	var selected_set = -1
	var selected_terrain = -1
	if terrain_info.has("set"):
		selected_set = terrain_info["set"]
	if terrain_info.has("terrain"):
		selected_terrain = terrain_info["terrain"]

	for cell in unique_cells:
		var mask: TerrainMask = masks.get(cell, null)
		if mask == null:
			for layer in layers:
				layer.erase_cell(cell)
			continue

		# 获取每个地形的掩码字典
		var terrain_masks = mask.get_terrain_masks()
		if terrain_masks.is_empty():
			# 所有角都是 -1，清除所有层
			for layer in layers:
				layer.erase_cell(cell)
			continue

		# 将地形 ID 排序，确保分配顺序一致
		var terrain_ids = terrain_masks.keys()
		terrain_ids.sort()
		# 最多支持四个地形
		if terrain_ids.size() > 4:
			# 只取前四个，并发出警告
			print("警告：格子 %s 包含超过 4 种地形，只处理前 4 个" % cell)
			terrain_ids = terrain_ids.slice(0, 4)

		# 为每个地形分配一个层索引（0~3）
		for layer_idx in range(4):
			var layer = layers[layer_idx]
			if layer_idx < terrain_ids.size():
				var terrain_id = terrain_ids[layer_idx]
				var terrain_mask_value = terrain_masks[terrain_id]
				# 查找匹配该掩码的瓦片
				var found = false
				for i in range(tile_set.get_source_count()):
					var source_id = tile_set.get_source_id(i)
					var full_mask = terrain_mask_value | (1 << 4)   # 假定中心位为当前地形
					var coords = find_tile_by_mask_probability(tile_set, source_id, selected_set, terrain_id, full_mask)
					if coords != null:
						layer.set_cell(cell, source_id, coords)
						found = true
						break
				if not found:
					# 没找到，擦除
					layer.erase_cell(cell)
			else:
				# 多余的层擦除
				layer.erase_cell(cell)

# 修改单角后生成新掩码
func get_mask_after_modify(cell: Vector2i, corner_idx: int, terrain_id: int) -> TerrainMask:
	var mask = get_cell_mask(cell)
	mask.set_corner(corner_idx, terrain_id)
	return mask

# 批量笔刷修改地形（支持任意半径）
func apply_modify_brush():
	var terrain_info = get_selected_terrain_info()
	var selected_set = -1
	var selected_terrain = -1
	if terrain_info.has("set"):
		selected_set = terrain_info["set"]
	if terrain_info.has("terrain"):
		selected_terrain = terrain_info["terrain"]

	if ( selected_set == -1 || selected_terrain == -1 ):
		return
	
	# 获取笔刷所有顶点+对应格子角
	var vert_map = get_brush_affected_vertices(current_hit_tile, current_hit_corner_idx, brush_slider.value)
	if vert_map.is_empty():
		return

	# 统一存储所有受影响格子+新掩码
	var cell_masks:Dictionary[Vector2i, TerrainMask] = {}

	# 遍历笔刷内全部顶点，逐个修改对应格子角
	for vert in vert_map.keys():
		var cell_cor_list = vert_map[vert]
		for pair in cell_cor_list:
			var cell = pair[0]
			var cor_idx = pair[1]
			# 已有掩码则复用，无则读取原始掩码
			var mask:TerrainMask
			if cell_masks.has(cell):
				mask = cell_masks[cell]
			else:
				mask = get_cell_mask(cell)
			# 修改当前角地形
			mask.set_corner(cor_idx, selected_terrain)
			cell_masks[cell] = mask

	# 批量刷新瓦片图层
	sync_cell_display(cell_masks.keys(), cell_masks)
	# 更新预览格子
	var affected_cells = get_brush_affected_cells(current_hit_tile, current_hit_corner_idx, brush_slider.value)
	if affected_cells != hover_cells:
		hover_cells = affected_cells
		update_overlays()

# 批量擦除笔刷（角置为-1）
func apply_erase_brush():
	if !target_container || !target_container.tile_set:
		return
	var vert_map = get_brush_affected_vertices(current_hit_tile, current_hit_corner_idx, brush_slider.value)
	if vert_map.is_empty():
		return

	var cell_masks:Dictionary[Vector2i, TerrainMask] = {}
	for vert in vert_map.keys():
		var cell_cor_list = vert_map[vert]
		for pair in cell_cor_list:
			var cell = pair[0]
			var cor_idx = pair[1]
			var mask:TerrainMask
			if cell_masks.has(cell):
				mask = cell_masks[cell]
			else:
				mask = get_cell_mask(cell)
			mask.set_corner(cor_idx, -1)
			cell_masks[cell] = mask

	sync_cell_display(cell_masks.keys(), cell_masks)

# 撤销
func save_modify_snapshot():
	var layers = target_container.get_corner_layers()
	initial_data.clear()
	for layer in layers:
		initial_data.append(layer.tile_map_data.duplicate())
	has_modified = true

# 重做
func commit_undo_record():
	if !has_modified:
		return
	var layers = target_container.get_corner_layers()
	var undo = get_undo_redo()
	undo.create_action("笔刷修改地形(半径%d)" % brush_slider.value)
	for i in range(layers.size()):
		undo.add_do_property(layers[i], "tile_map_data", layers[i].tile_map_data)
		undo.add_undo_property(layers[i], "tile_map_data", initial_data[i])
	undo.commit_action()
	has_modified = false

func _handles(object: Object) -> bool:
	return object is War3TileMapLayer

# 视口绘制覆盖层（预览+调试文字）
func _forward_canvas_draw_over_viewport(viewport_control: Control):
	if !target_container || !target_container.tile_set || !target_container.has_all_corner_layers():
		return
	var tile_set = target_container.tile_set
	var shape = tile_set.tile_shape
	var sample_layer = target_container.get_corner_layers()[0]

	var terrain_info = get_selected_terrain_info()
	var selected_set = -1
	var selected_terrain = -1
	if terrain_info.has("set"):
		selected_set = terrain_info["set"]
	if terrain_info.has("terrain"):
		selected_terrain = terrain_info["terrain"]

	#选中地形集才预览
	if selected_set != -1:
		# 绘制层级顺序：底层网格边框 → 红色角标记 → 鼠标外圈（由后往前绘制）
		# 1. 笔刷预览瓦片边框（底层，淡蓝色）
		if hover_cells.size() > 0:
			# 去重缓存，避免重复绘制同一格子
			var drawn_cell_set: Dictionary[Vector2i, bool] = {}
			for cell in hover_cells:
				if drawn_cell_set.has(cell):
					continue
				drawn_cell_set[cell] = true
				var local_verts = get_tile_local_verts(cell, tile_set)
				if local_verts.size() < 4:
					continue
				# 转换全部顶点到GUI画布坐标
				var gui_points: PackedVector2Array = []
				for v in local_verts:
					gui_points.append(tile_local_to_gui(v))
				# 闭合绘制四边形边框
				var point_count = gui_points.size()
				for i in range(point_count):
					var p0 = gui_points[i]
					var p1 = gui_points[(i + 1) % point_count]
					viewport_control.draw_line(p0, p1, Color.LIGHT_GRAY, 2.0)

	# 底部调试文字
	var view_size = viewport_control.get_size()
	var font = ThemeDB.fallback_font
	var font_size = 20
	var line_gap = font_size + 4
	var draw_pos = Vector2(32, view_size.y - 8)
	var shape_name
	match shape:
		TileSet.TILE_SHAPE_SQUARE: shape_name = "Square方格"
		TileSet.TILE_SHAPE_ISOMETRIC: shape_name = "Isometric等距"
		_: shape_name = "不支持类型"
	var corner_labels
	if shape == TileSet.TILE_SHAPE_SQUARE:
		corner_labels = ["左上","右上","右下","左下"]
	else:
		corner_labels = ["左","上","右","下"]
	
	var text_lines = [
		"网格: %s | 笔刷半径: %d" % [shape_name, brush_slider.value],
		"瓦片: (%d, %d) 命中角: %s" % [current_hit_tile.x, current_hit_tile.y, corner_labels[current_hit_corner_idx]],
	]
	# 文字增加黑色描边，防止被网格覆盖看不清
	for line in text_lines:
		# 描边
		viewport_control.draw_string(font, draw_pos + Vector2(1,1), line, 0, -1, font_size, Color.BLACK)
		viewport_control.draw_string(font, draw_pos, line, 0, -1, font_size, Color.YELLOW)
		draw_pos.y -= line_gap

# 视口鼠标输入处理
func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if !target_container || !target_container.tile_set || !target_container.has_all_corner_layers() || !(event is InputEventMouse):
		return false

	var terrain_info = get_selected_terrain_info()
	var selected_set = -1
	var selected_terrain = -1
	if terrain_info.has("set"):
		selected_set = terrain_info["set"]
	if terrain_info.has("terrain"):
		selected_terrain = terrain_info["terrain"]

	if selected_set == -1:
		return false
	
	var mouse_event = event as InputEventMouse
	var vp_ctrl = EditorInterface.get_editor_viewport_2d()
	var gui_mouse = mouse_event.position
	var local_pos = gui_mouse_to_tile_local(gui_mouse)
	var sample_layer = target_container.get_corner_layers()[0]
	current_hit_tile = sample_layer.local_to_map(local_pos)
	var tile_pos = current_hit_tile
	var tile_set = target_container.tile_set
	var tile_cor_data = calc_tile_local_corners(tile_pos, tile_set)
	current_hit_corner_idx = get_hit_corner(gui_mouse)
	hover_cells = get_brush_affected_cells(current_hit_tile,current_hit_corner_idx,brush_slider.value)

	# 鼠标移动：仅预览，不重复存快照
	if mouse_event is InputEventMouseMotion:
		update_overlays()
		if is_left_dragging:
			# 拖拽绘制，不重复save快照，按下时已保存
			apply_modify_brush()
		elif is_right_dragging:
			apply_erase_brush()
		vp_ctrl.set_input_as_handled()
		return true

	# 鼠标按键
	if mouse_event is InputEventMouseButton:
		var btn_event = mouse_event as InputEventMouseButton
		match btn_event.button_index:
			MOUSE_BUTTON_LEFT:
				if btn_event.pressed:
					is_left_dragging = true
					# 仅按下瞬间保存1次原始快照
					save_modify_snapshot()
					apply_modify_brush()
				else:
					is_left_dragging = false
					# 松开统一提交1条undo
					if has_modified:
						commit_undo_record()
			MOUSE_BUTTON_RIGHT:
				if btn_event.pressed:
					is_right_dragging = true
					save_modify_snapshot()
					apply_erase_brush()
				else:
					is_right_dragging = false
					if has_modified:
						commit_undo_record()
		vp_ctrl.set_input_as_handled()
		return true
	return false
