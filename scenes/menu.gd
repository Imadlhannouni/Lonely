extends Control

func _ready() -> void:
	setup_background()
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)

	# Logo
	var logo := TextureRect.new()
	logo.texture = load("res://icons/Logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(500, 250)
	vbox.add_child(logo)

	# Création des boutons avec couleurs d'accentuation
	var start_btn = create_premium_button("START", Color(0.0, 0.0, 0.0, 1.0))
	var exit_btn = create_premium_button("EXIT", Color(0.0, 0.0, 0.0, 1.0))
	
	vbox.add_child(start_btn)
	vbox.add_child(exit_btn)

	# Connexions
	start_btn.pressed.connect(_on_start_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

func setup_background() -> void:
	# Musique
	var audio = AudioStreamPlayer.new()
	audio.stream = load("res://audio/dark-ambiant.mp3")
	audio.autoplay = true
	add_child(audio)
	
	# Image de fond
	var bg = TextureRect.new()
	bg.texture = load("res://bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.4, 0.4, 0.4) # Assombrit l'image de fond
	add_child(bg)

func create_premium_button(txt: String, accent_color: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(350, 75)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pivot_offset = Vector2(175, 37.5) # Centre exact (350/2, 75/2)
	
	# Style Normal
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	sb_normal.set_corner_radius_all(10)
	sb_normal.border_width_left = 5 # Barre latérale stylisée
	sb_normal.border_color = accent_color
	sb_normal.shadow_color = Color(0, 0, 0, 0.5)
	sb_normal.shadow_size = 12
	sb_normal.shadow_offset = Vector2(0, 4)
	
	# Style Hover (Survol)
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(0.15, 0.15, 0.18)
	sb_hover.border_color = accent_color.lightened(0.4)
	sb_hover.shadow_size = 20
	
	# Style Pressed
	var sb_pressed = sb_normal.duplicate()
	sb_pressed.bg_color = Color(0.05, 0.05, 0.05)
	sb_pressed.border_width_left = 10 # Accentuation visuelle du clic
	
	# Application des thèmes
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", accent_color)

	# --- LOGIQUE D'ANIMATION ---
	btn.mouse_entered.connect(func():
		var t = create_tween().set_parallel(true)
		t.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "modulate", Color(1.3, 1.3, 1.3), 0.2)
	)
	
	btn.mouse_exited.connect(func():
		var t = create_tween().set_parallel(true)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
		t.tween_property(btn, "modulate", Color.WHITE, 0.2)
	)
	
	return btn

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
