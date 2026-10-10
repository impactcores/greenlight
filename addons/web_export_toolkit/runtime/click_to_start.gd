extends CanvasLayer
## Simple start screen. Browsers dont play audio before the first click,
## so we just ask for one. Classic "why is there no sound on itch" problem.

var prompt := "Click to start"
var background := Color(0.06, 0.06, 0.09, 1.0)
var text_color := Color(1, 1, 1, 0.9)

var _label: Label
var _time := 0.0


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = background
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_label = Label.new()
	_label.text = prompt
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", text_color)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(_label)


func _process(delta: float) -> void:
	# little pulse so it doesnt look frozen while teh player looks at it
	_time += delta
	_label.modulate.a = 0.6 + 0.4 * absf(sin(_time * 2.0))


func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
		pressed = event.is_pressed()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var owner_node := get_parent()
	if owner_node and owner_node.has_method("_on_screen_started"):
		owner_node._on_screen_started()
	queue_free()
