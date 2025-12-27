extends Control

# Chemin vers la scène de jeu principale
var game_scene_path = "res://scenes/main.tscn"  # Ajuste selon le nom de ta scène de jeu

@onready var start_button: Button = null
@onready var settings_button: Button = null
@onready var exit_button: Button = null

func _ready() -> void:
	# Fond clair élégant avec dégradé
	var bg = ColorRect.new()
	bg.color = Color(0.75, 0.76, 0.78, 1.0)  # Gris doux
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Créer le conteneur principal centré
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 15)
	add_child(container)
	
	# Centrer automatiquement le conteneur
	container.anchor_left = 0.5
	container.anchor_right = 0.5
	container.anchor_top = 0.5
	container.anchor_bottom = 0.5
	container.offset_left = -250  # moitié de la largeur des boutons
	container.offset_top = -250   # moitié de la hauteur approximative du conteneur
	container.offset_right = 250
	container.offset_bottom = 250
	
	# Logo du jeu
	var logo = TextureRect.new()
	logo.texture = load("res://icons/Logo.png")
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(450, 180)
	container.add_child(logo)
	
	# Espacement
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 60)
	container.add_child(spacer1)
	
	# Bouton Lancer
	start_button = create_styled_button("▶ Lancer", Color(0.15, 0.15, 0.15))  # Noir/gris foncé
	start_button.pressed.connect(_on_start_pressed)
	container.add_child(start_button)
	
	# Bouton Settings
	settings_button = create_styled_button("⚙ Settings", Color(0.25, 0.25, 0.25))  # Gris foncé
	settings_button.pressed.connect(_on_settings_pressed)
	container.add_child(settings_button)
	
	# Bouton Exit
	exit_button = create_styled_button("✕ Exit", Color(0.35, 0.35, 0.35))  # Gris moyen
	exit_button.pressed.connect(_on_exit_pressed)
	container.add_child(exit_button)

func create_styled_button(text: String, base_color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(450, 55)
	
	# Style du bouton
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.corner_radius_top_left = 12
	style_normal.corner_radius_top_right = 12
	style_normal.corner_radius_bottom_left = 12
	style_normal.corner_radius_bottom_right = 12
	style_normal.shadow_color = Color(0, 0, 0, 0.2)
	style_normal.shadow_size = 8
	style_normal.shadow_offset = Vector2(0, 4)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = base_color.lightened(0.15)
	style_hover.corner_radius_top_left = 12
	style_hover.corner_radius_top_right = 12
	style_hover.corner_radius_bottom_left = 12
	style_hover.corner_radius_bottom_right = 12
	style_hover.shadow_color = Color(0, 0, 0, 0.3)
	style_hover.shadow_size = 12
	style_hover.shadow_offset = Vector2(0, 6)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.05, 0.05, 0.05)  # Noir profond
	style_pressed.corner_radius_top_left = 12
	style_pressed.corner_radius_top_right = 12
	style_pressed.corner_radius_bottom_left = 12
	style_pressed.corner_radius_bottom_right = 12
	style_pressed.shadow_color = Color(0, 0, 0, 0.15)
	style_pressed.shadow_size = 4
	style_pressed.shadow_offset = Vector2(0, 2)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
	
	return button

func _on_start_pressed() -> void:
	# Charger la scène de jeu
	get_tree().change_scene_to_file(game_scene_path)

func _on_settings_pressed() -> void:
	print("Settings - À implémenter plus tard")

func _on_exit_pressed() -> void:
	get_tree().quit()
