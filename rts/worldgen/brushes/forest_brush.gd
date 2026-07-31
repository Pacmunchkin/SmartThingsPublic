@tool
class_name ForestBrush
extends WorldBrush

## Plants wildwood.
##
## With no Polygon2D child it covers the whole map, which is what the first
## brush in a level normally wants. Add a polygon and it only plants inside it,
## so a level can have several woods with different spacing and species mixes -
## dense oak on the valley floor, thin thorn on the tops.
##
## Brushes below this one in the tree subtract from what it plants. That is the
## whole authoring model: plant everything, then let the water, the rock and
## the people take their share out.

@export_range(6.0, 60.0, 0.5) var spacing: float = 14.0:
	set(value):
		spacing = value
		request_rebuild()
## Below this noise value no tree stands. Higher opens more glades.
@export_range(0.0, 0.8, 0.02) var glade_threshold: float = 0.16:
	set(value):
		glade_threshold = value
		request_rebuild()
## Multiplies every trunk's size. Use under 1 for scrub and coppice.
@export_range(0.3, 2.0, 0.05) var tree_scale: float = 1.0:
	set(value):
		tree_scale = value
		request_rebuild()


func apply(world: WorldData) -> void:
	var region := polygon_points()
	var planted := ForestStage.plant(world, region, spacing, glade_threshold, tree_scale)
	world.note("forest", "%s planted %d trees%s"
		% [name, planted, "" if region.is_empty() else " inside its polygon"])
