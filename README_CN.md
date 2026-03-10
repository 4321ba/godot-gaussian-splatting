# gdgs

[English README](README.md)

一个基于 `CompositorEffect` 和计算着色器的 Godot 4 Gaussian Splatting 插件。

`gdgs` 可以导入支持的 3DGS `.ply` 资源，通过 `GaussianSplatNode` 放入 Godot 场景，并使用场景深度与常规 3D 场景进行混合合成。

## 功能特性

- 将支持的 Gaussian Splat `.ply` 文件导入为 Godot 资源。
- 在同一个场景中渲染一个或多个 `GaussianSplatNode`。
- 通过 `WorldEnvironment.compositor` 将 Gaussian Splat 渲染结果与标准 Godot 3D 内容合成。
- 基于场景深度进行遮挡混合。
- 支持编辑器预览和 gizmo。
- 内置 alpha、颜色、GS 深度、场景深度和深度剔除掩码等调试视图。

## 环境要求

- Godot `4.4` 或更新版本。
- 使用 `Forward Plus` 渲染后端。
- 支持计算着色器的桌面 GPU 和驱动。
- 一个符合要求的 Gaussian Splat 二进制 `.ply` 文件。

## 安装方法

1. 将 `addons/gdgs` 文件夹复制到你的 Godot 项目中。
2. 用 Godot 打开该项目。
3. 进入 `Project > Project Settings > Plugins`。
4. 启用 `gdgs` 插件。

## 快速开始

1. 将支持的 `.ply` 文件加入项目。
2. 等待 Godot 将其导入为资源。
3. 在场景中添加一个 `GaussianSplatNode`。
4. 将导入后的资源赋值给 `GaussianSplatNode` 的 `gaussian` 属性。
5. 在场景中添加一个 `WorldEnvironment` 节点。
6. 在 `WorldEnvironment.compositor` 上创建一个 `Compositor` 资源。
7. 在该 `Compositor` 中添加一个 `CompositorEffect`，并将它的脚本设置为 `res://addons/gdgs/postprocess.gd`。
8. 运行场景。

仓库中的 `node_3d.tscn` 可以作为最小可运行示例参考。

## 场景配置说明

- `GaussianSplatNode` 是一个用于承载变换和资源引用的场景节点，实际渲染由 compositor pass 完成，而不是通过 Godot 标准 mesh 渲染管线完成。
- 当前支持多个 `GaussianSplatNode`，它们会在同一个 Gaussian 渲染 pass 中统一渲染。
- 如果你替换了源 `.ply` 文件的内容，请在 Godot 中重新导入，确保生成的资源与源文件保持同步。

## 后处理参数

compositor effect 脚本位于 `res://addons/gdgs/postprocess.gd`。

- `alpha_cutoff`：alpha 低于该阈值的像素在最终合成时会被忽略。
- `depth_bias`：GS 深度与场景深度比较时使用的小偏移量。
- `depth_test_min_alpha`：只有当 GS alpha 高于该阈值时才应用深度剔除。
- `debug_view`：调试输出模式。

`debug_view` 可选项：

- `Composite`：最终合成结果。
- `GS Alpha`：Gaussian alpha 缓冲。
- `GS Color`：Gaussian 颜色缓冲。
- `GS Depth`：Gaussian 深度缓冲。
- `Scene Depth`：场景深度缓冲。
- `Depth Reject Mask`：显示哪些 GS 像素因为深度测试被剔除。

## 支持的 PLY 格式

导入器要求 Gaussian Splat PLY 至少包含以下属性：

- 位置：`x`、`y`、`z`
- DC 颜色系数：`f_dc_0`、`f_dc_1`、`f_dc_2`
- 其余 SH 系数：`f_rest_0` 到 `f_rest_44`
- 不透明度：`opacity`
- 缩放：`scale_0`、`scale_1`、`scale_2`
- 旋转：`rot_0`、`rot_1`、`rot_2`、`rot_3`

该导入器面向 3D Gaussian Splatting 风格资源，不适用于普通点云 `.ply` 文件。

## 仓库结构

- `addons/gdgs/gaussian`：PLY 导入器和 Gaussian 资源定义。
- `addons/gdgs/node`：场景节点和编辑器 gizmo。
- `addons/gdgs/rendering`：渲染管理器、渲染上下文和计算着色器。
- `addons/gdgs/postprocess.gd`：Compositor effect 入口。

## 已知限制

- 当前插件仅面向桌面端 `Forward Plus` 渲染。
- 渲染依赖 Godot 的 compositor 和 compute 管线，因此不支持 compatibility/mobile 渲染器。
- 当前渲染管理器仍然以共享的 root 级运行时管理器存在，极端复杂的编辑器多场景或多视口工作流仍然需要进一步验证。
- 导入器依赖特定的 Gaussian Splat 属性布局。

## 示例资源

仓库中包含示例资源和示例场景：

- `node_3d.tscn`
- `demo.ply`
- `zqbx.ply`
