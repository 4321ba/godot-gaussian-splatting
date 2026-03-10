# gdgs

[中文说明](README_CN.md)

A Gaussian Splatting plugin for Godot 4 based on `CompositorEffect` and compute shaders.

`gdgs` can import supported 3DGS `.ply` assets, place them in a Godot scene through `GaussianSplatNode`, and composite the result with the regular 3D scene using scene depth.

## Features

- Import supported Gaussian Splat `.ply` files as Godot resources.
- Render one or more `GaussianSplatNode` instances in the same scene.
- Composite Gaussian Splat rendering with standard Godot 3D content through `WorldEnvironment.compositor`.
- Depth-aware mixing with the scene depth buffer.
- Editor-side preview support and gizmo support.
- Built-in debug views for alpha, color, GS depth, scene depth, and depth rejection.

## Requirements

- Godot `4.4` or newer.
- `Forward Plus` rendering backend.
- A desktop GPU and driver with compute shader support.
- A supported binary Gaussian Splat `.ply` file.

## Installation

1. Copy the `addons/gdgs` folder into your Godot project.
2. Open the project in Godot.
3. Go to `Project > Project Settings > Plugins`.
4. Enable the `gdgs` plugin.

## Quick Start

1. Add a supported `.ply` file to the project.
2. Wait for Godot to import it into a resource.
3. Add a `GaussianSplatNode` to your scene.
4. Assign the imported resource to the `gaussian` property of `GaussianSplatNode`.
5. Add a `WorldEnvironment` node to the scene.
6. Create a `Compositor` resource on `WorldEnvironment.compositor`.
7. Add a `CompositorEffect` to that `Compositor`, and set its script to `res://addons/gdgs/postprocess.gd`.
8. Run the scene.

You can use `node_3d.tscn` in the repository as a minimal reference scene.

## Scene Setup Notes

- `GaussianSplatNode` is a scene object used to hold transform and resource references. Actual rendering is performed by the compositor pass, not by Godot's standard mesh pipeline.
- Multiple `GaussianSplatNode` instances are supported and are rendered together in the same Gaussian pass.
- If you replace the source `.ply` file contents, reimport it in Godot so the generated resource stays in sync.

## Post Process Parameters

The compositor effect script is `res://addons/gdgs/postprocess.gd`.

- `alpha_cutoff`: Pixels with alpha below this threshold are ignored during final composition.
- `depth_bias`: Small bias used when comparing GS depth against scene depth.
- `depth_test_min_alpha`: Minimum GS alpha required before depth rejection is applied.
- `debug_view`: Debug output mode.

`debug_view` options:

- `Composite`: Final composited result.
- `GS Alpha`: Gaussian alpha buffer.
- `GS Color`: Gaussian color buffer.
- `GS Depth`: Gaussian depth buffer.
- `Scene Depth`: Scene depth buffer.
- `Depth Reject Mask`: Shows which GS pixels are rejected by depth testing.

## Supported PLY Format

The importer expects a Gaussian Splat PLY with the following properties:

- Position: `x`, `y`, `z`
- DC color coefficients: `f_dc_0`, `f_dc_1`, `f_dc_2`
- Remaining SH coefficients: `f_rest_0` to `f_rest_44`
- Opacity: `opacity`
- Scale: `scale_0`, `scale_1`, `scale_2`
- Rotation: `rot_0`, `rot_1`, `rot_2`, `rot_3`

This importer is meant for 3D Gaussian Splatting style assets, not generic point cloud `.ply` files.

## Repository Layout

- `addons/gdgs/gaussian`: PLY importer and Gaussian resource definitions.
- `addons/gdgs/node`: Scene node and editor gizmo.
- `addons/gdgs/rendering`: Render manager, rendering context, and compute shaders.
- `addons/gdgs/postprocess.gd`: Compositor effect entry point.

## Known Limitations

- The plugin currently targets desktop Forward Plus rendering only.
- Rendering depends on Godot's compositor and compute pipeline, so compatibility/mobile renderers are not supported.
- The render manager currently lives as a shared root-level runtime manager, so very complex editor multi-scene or multi-viewport workflows may still need additional validation.
- The importer expects a specific Gaussian Splat property layout.

## Demo

The repository includes sample assets and a sample scene:

- `node_3d.tscn`
- `demo.ply`
- `zqbx.ply`
