# =============================================================================
# GPU-Ready 内存布局说明 (std430 标准)
# =============================================================================
# point_data 是一个扁平的 PackedByteArray，由多个定长 Struct 首尾相连组成。
# 单个高斯点 (Splat) 占用 60 个 Float32 (即 240 Bytes)。
# 数据严格按照 GLSL std430 内存布局组装，可直接零拷贝 (Zero-copy) 传给 GPU Buffer。
#
# [偏移量 (Float)] | [数据类型]   | [说明]
# -----------------------------------------------------------------------------
# Offset  0 ~  2  | vec3         | 中心位置 (Position: X, Y, Z)
# Offset  3       | float        | 创建时间 (Creation Time) - 对齐 vec4，可用于特效
# Offset  4 ~  9  | float[6]     | 3D 协方差矩阵的上三角 (Covariance 3D) 排列顺序: xx, xy, xz, yy, yz, zz
# Offset 10       | float        | 不透明度 (Opacity) - 已完成 Sigmoid 映射 (0.0~1.0)
# Offset 11       | float        | 内存对齐 (Padding) - 保证后续数据在 vec4 边界上
# Offset 12 ~ 14  | vec3         | 球谐函数基础色 (SH DC) - 0阶系数 (R, G, B)
# Offset 15 ~ 59  | float[45]    | 球谐函数视角反射 (SH Rest) - 1到3阶系数，已通过重排(Swizzle)转为 RGB 交替: R0,G0,B0, R1,G1,B1...
# =============================================================================
# 总计: 60 个 float = 240 bytes / 点
# =============================================================================
@tool
extends Resource
class_name GaussianResource  # 关键：定义类名，让 Godot 认识它

@export var point_count: int = 0
@export var point_data_float: PackedFloat32Array  # 存储float格式的数据
@export var point_data_byte : PackedByteArray     # 直接存储 GPU-ready 的纯净二进制数据
@export var xyz : PackedVector3Array
@export var aabb : AABB = AABB()
