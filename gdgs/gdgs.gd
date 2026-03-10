@tool
extends EditorPlugin

const MANAGER_NODE_NAME := "_GdgsGaussianRenderManager"

var importer
var gizmo_plugin

func _enter_tree() -> void:
	importer = preload("res://addons/gdgs/gaussian/GaussianImporter.gd").new()
	add_import_plugin(importer)

	gizmo_plugin = preload("res://addons/gdgs/node/GaussianGizmo.gd").new()
	add_node_3d_gizmo_plugin(gizmo_plugin)

	print("[gdgs] enable gaussian splatting plugin")

func _exit_tree() -> void:
	if importer != null:
		remove_import_plugin(importer)
	if gizmo_plugin != null:
		remove_node_3d_gizmo_plugin(gizmo_plugin)

	var tree := get_tree()
	if tree != null and tree.root != null:
		var manager := tree.root.get_node_or_null(MANAGER_NODE_NAME)
		if manager != null:
			if manager.has_method("shutdown"):
				manager.shutdown()
			manager.queue_free()

	print("[gdgs] disable gaussian splatting plugin")
