# =============================================================================
# 文件：res://addons/gdgs/gaussian/GaussianImporter.gd
# 读取ply文件，并且转化为GPU-ready格式
# =============================================================================
@tool
extends EditorImportPlugin

const GaussianResourceScript = preload("res://addons/gdgs/gaussian/GaussianResource.gd")


# 内置解析函数
class InternalPlyParser:
	var size: int = 0
	var properties: Array[StringName] = []
	var vertices: PackedFloat32Array = PackedFloat32Array()

	func parse(path: String) -> Error:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()

		# 跳过第一行的 "ply" 魔法字
		var magic := file.get_line().strip_edges()
		if magic != "ply":
			push_error("PLY format error: Missing 'ply' magic word.")
			return ERR_FILE_UNRECOGNIZED

		var line := file.get_line().strip_edges().split(" ", false)
		while line.size() > 0 and line[0] != "end_header":
			match line[0]:
				"format":
					if line.size() > 1:
						file.big_endian = (line[1] == "binary_big_endian")
				"element":
					if line.size() > 2 and line[1] == "vertex":
						size = int(line[2])
				"property":
					if line.size() > 2:
						properties.push_back(line[2])
			line = file.get_line().strip_edges().split(" ", false)

		if size <= 0 or properties.is_empty():
			return ERR_INVALID_DATA

		# 读取所有顶点数据 (每个 float 是 4 字节)
		var byte_size := size * properties.size() * 4
		var buffer := file.get_buffer(byte_size)
		vertices = buffer.to_float32_array()
		return OK

	func get_property_index_map() -> Dictionary:
		var map := {}
		for i in range(properties.size()):
			map[properties[i]] = i
		return map


# -----------------------------------------------------------------------------
# 导入器配置
# -----------------------------------------------------------------------------
func _get_priority() -> float:
	return 2.0


func _get_import_order() -> int:
	return 0


func _get_importer_name() -> String:
	return "gaussian.splat.importer"


func _get_visible_name() -> String:
	return "Gaussian Splat (.ply)"


func _get_recognized_extensions() -> PackedStringArray:
	return ["ply"]


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"  # 必须return Resource，用GaussianResource会报错


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	return "Default"


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return []


# -----------------------------------------------------------------------------
# 导入主流程
# -----------------------------------------------------------------------------
func _import(source_file, save_path, options, platform_variants, gen_files) -> Error:
	print("[gdgs]: 正在导入 3DGS PLY 文件: %s" % source_file)

	var ply := InternalPlyParser.new()
	var parse_error: Error = ply.parse(source_file)
	if parse_error != OK:
		return parse_error

	var prop_map: Dictionary = ply.get_property_index_map()

	# 确保高斯属性齐全
	var required := [
		"x", "y", "z", "f_dc_0", "f_dc_1", "f_dc_2", "opacity", "scale_0", "scale_1", "scale_2", "rot_0", "rot_1", "rot_2", "rot_3"
	]
	for i in 45:
		required.append("f_rest_%d" % i)

	for name in required:
		if not prop_map.has(name):
			return ERR_INVALID_DATA

	# 提取索引以提升循环速度
	var idx_x: int = prop_map["x"]
	var idx_y: int = prop_map["y"]
	var idx_z: int = prop_map["z"]
	var idx_fdc0: int = prop_map["f_dc_0"]
	var idx_fdc1: int = prop_map["f_dc_1"]
	var idx_fdc2: int = prop_map["f_dc_2"]
	var idx_opac: int = prop_map["opacity"]
	var idx_s0: int = prop_map["scale_0"]
	var idx_s1: int = prop_map["scale_1"]
	var idx_s2: int = prop_map["scale_2"]
	var idx_r0: int = prop_map["rot_0"]
	var idx_r1: int = prop_map["rot_1"]
	var idx_r2: int = prop_map["rot_2"]
	var idx_r3: int = prop_map["rot_3"]

	var rest_idx: Array[int] = []
	rest_idx.resize(45)
	for i in 45:
		rest_idx[i] = prop_map["f_rest_%d" % i]

	var count: int = ply.size
	var num_props: int = ply.properties.size()
	var p: PackedFloat32Array = ply.vertices

	# === 核心：准备 GPU 数据布局 (AoS) ===
	var STRUCT_SIZE := 60  # 每个高斯点占据 60 个 float

	# AoS布局，GPU-ready的格式
	var points := PackedFloat32Array()
	points.resize(count * STRUCT_SIZE)

	# xyz和AABB包围框的边界
	var xyz := PackedVector3Array()
	xyz.resize(count)
	var aabb_min_v := Vector3(INF, INF, INF)
	var aabb_max_v := Vector3(-INF, -INF, -INF)

	for i in count:
		var v_base := i * num_props  # 原属性数组起始位
		var b := i * STRUCT_SIZE  # 目标 std430 数组起始位

		# 1. 位置 & 创建时间
		var pos := Vector3(p[v_base + idx_x], p[v_base + idx_y], p[v_base + idx_z])
		xyz[i] = pos
		aabb_min_v = aabb_min_v.min(pos)
		aabb_max_v = aabb_max_v.max(pos)
		points[b + 0] = p[v_base + idx_x]
		points[b + 1] = p[v_base + idx_y]
		points[b + 2] = p[v_base + idx_z]
		points[b + 3] = 0.0  # 预留时间字段

		# 2. 计算 3D 协方差 (Covariance)
		var scale_mat := Basis.from_scale(
			Vector3(exp(p[v_base + idx_s0]), exp(p[v_base + idx_s1]), exp(p[v_base + idx_s2]))
		)
		var rot_mat := Basis(
			Quaternion(p[v_base + idx_r1], p[v_base + idx_r2], p[v_base + idx_r3], p[v_base + idx_r0])
		).transposed()
		var cov_3d := (scale_mat * rot_mat).transposed() * (scale_mat * rot_mat)

		points[b + 4] = cov_3d.x[0]
		points[b + 5] = cov_3d.y[0]
		points[b + 6] = cov_3d.z[0]
		points[b + 7] = cov_3d.y[1]
		points[b + 8] = cov_3d.z[1]
		points[b + 9] = cov_3d.z[2]

		# 3. 预计算不透明度 (Sigmoid)
		points[b + 10] = 1.0 / (1.0 + exp(-p[v_base + idx_opac]))
		points[b + 11] = 0.0  # Padding 对齐位

		# 4. 球谐系数 DC (0阶)
		points[b + 12] = p[v_base + idx_fdc0]
		points[b + 13] = p[v_base + idx_fdc1]
		points[b + 14] = p[v_base + idx_fdc2]

		# 5. 球谐系数 Rest (高级交叉排列)
		for k in range(0, 45, 3):
			var sh_idx = k / 3
			points[b + k + 15] = p[v_base + rest_idx[sh_idx + 0]]  # Red
			points[b + k + 16] = p[v_base + rest_idx[sh_idx + 15]]  # Green
			points[b + k + 17] = p[v_base + rest_idx[sh_idx + 30]]  # Blue

	# 存入资源
	var g_res = GaussianResourceScript.new()
	g_res.point_count = count
	g_res.point_data_float = points
	g_res.point_data_byte = points.to_byte_array()  # 转化为二进制字节流！
	g_res.xyz = xyz
	if count > 0:
		g_res.aabb = AABB(aabb_min_v, aabb_max_v - aabb_min_v)
	else:
		g_res.aabb = AABB()

	var filename = "%s.%s" % [save_path, _get_save_extension()]
	var error = ResourceSaver.save(g_res, filename)
	if error != OK:
		push_error("[gdgs]: 保存资源失败, 错误码: %d" % error)
	else:
		print("[gdgs]: 导入完成！预处理了 %d 个高斯点。" % count)

	return error
