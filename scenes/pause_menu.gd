extends CanvasLayer

@onready var continue_button: Button = null
@onready var settings_button: Button = null
@onready var return_menu_button: Button = null
@onready var exit_button: Button = null

func _ready() -> void:
	layer = 100  # Au-dessus de tout
	process_mode = PROCESS_MODE_ALWAYS  # Continue de fonctionner même en pause
	get_tree().paused = true  # Freeze le jeu
	
	# Fond semi-transparent
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = get_viewport().get_visible_rect().size
	add_child(bg)
	
	# Conteneur principal
	var container = VBoxContainer.new()
	container.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 100, get_viewport().get_visible_rect().size.y / 2 - 200)
	container.custom_minimum_size = Vector2(200, 400)
	add_child(container)
	
	# Titre
	var title = Label.new()
	title.text = "PAUSE"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)
	
	# Espacement
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 50)
	container.add_child(spacer1)
	
	# Bouton Continuer
	continue_button = Button.new()
	continue_button.text = "Continuer"
	continue_button.custom_minimum_size = Vector2(200, 50)
	continue_button.pressed.connect(_on_continue_pressed)
	container.add_child(continue_button)
	
	# Espacement
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer2)
	
	# Bouton Settings
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(200, 50)
	settings_button.pressed.connect(_on_settings_pressed)
	container.add_child(settings_button)
	
	# Espacement
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer3)
	
	# Bouton Return to Main Menu
	return_menu_button = Button.new()
	return_menu_button.text = "Return to Main Menu"
	return_menu_button.custom_minimum_size = Vector2(200, 50)
	return_menu_button.pressed.connect(_on_return_menu_pressed)
	container.add_child(return_menu_button)
	
	# Espacement
	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer4)
	
	# Bouton Exit
	exit_button = Button.new()
	exit_button.text = "Exit"
	exit_button.custom_minimum_size = Vector2(200, 50)
	exit_button.pressed.connect(_on_exit_pressed)
	container.add_child(exit_button)

func _on_continue_pressed() -> void:
	# Reprendre le jeu et fermer le menu pause
	get_tree().paused = false
	queue_free()

func _on_settings_pressed() -> void:
	print("Settings - À implémenter plus tard")

func _on_return_menu_pressed() -> void:
	# Reprendre le jeu et fermer le menu pause avant de retourner au menu principal
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_exit_pressed() -> void:
	# Quitter le jeu
	get_tree().quit()

func _input(event: InputEvent) -> void:
	# Fermer avec ESC
	if event.is_action_pressed("ui_cancel"):
		_on_continue_pressed()
