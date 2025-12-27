extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -500.0

@onready var light = $PointLight2D
@onready var start_timer = $Timer
var click_count = 0
var click_timer = 0.0
var lamp_sound: AudioStreamPlayer = null
var is_dead = false
var death_canvas: CanvasLayer = null

# Variables pour le système de lumières de chemin
var discovered_lights: Array[PointLight2D] = []  # Lumières découvertes par le joueur
static var saved_discovered_lights: Array[NodePath] = []  # Sauvegarder les chemins des lumières pour les respawns
const LIGHT_DETECTION_RADIUS = 150.0  # Rayon de détection des lumières
var all_scene_lights: Array[PointLight2D] = []  # Toutes les lumières de la scène
var death_messages := [
	"You learned something.",
	"Failure recorded.",
	"The path remembers you.",
	"Losing is progress.",
	"Another step forward."
]

@onready var death_voice: AudioStreamPlayer = null
@onready var bg_music: AudioStreamPlayer = null

# Variables pour la première tentative
static var is_first_try := true  # Static pour persister entre les rechargements
var intro_active := false
var intro_canvas: CanvasLayer = null

var death_audios := [
	preload("res://audio/AudioD.ogg"),
]

var background_music = preload("res://audio/dark-ambiant.mp3")
var lamp_sound_file = preload("res://audio/lamp.mp3")
var pause_menu_scene = preload("res://scenes/pause_menu.gd")
var pause_menu_instance = null


func _ready() -> void:
	position = Vector2(10, 600)
	
	# Initialiser le son de lampe
	if lamp_sound == null:
		lamp_sound = AudioStreamPlayer.new()
		add_child(lamp_sound)
		lamp_sound.stream = lamp_sound_file
	
	# Initialiser la musique de fond
	if bg_music == null:
		bg_music = AudioStreamPlayer.new()
		add_child(bg_music)
		bg_music.stream = background_music
		bg_music.volume_db = -10  # Ajuster le volume si nécessaire
		bg_music.autoplay = true
		if bg_music.stream:
			bg_music.stream.loop = true  # Activer la boucle
		bg_music.play()
	
	# Démarrer la lumière allumée et initialiser la séquence de clicks
	light.energy = 1.0
	click_count = 0
	click_timer = 0.0
	
	# Initialiser le système de lumières
	initialize_scene_lights()
	
	# Si première tentative, démarrer les clignotements
	if is_first_try:
		start_timer.start(10.0)  # Démarrer le timer avec une longue durée pour la séquence
	else:
		# Sinon, lumière directement allumée sans clignotement
		light.energy = 1.0

func _input(event: InputEvent) -> void:
	# Ouvrir le menu pause avec ESC
	if event.is_action_pressed("ui_cancel") and not is_dead and pause_menu_instance == null:
		open_pause_menu()

func open_pause_menu() -> void:
	# Créer et afficher le menu pause
	pause_menu_instance = CanvasLayer.new()
	pause_menu_instance.set_script(pause_menu_scene)
	get_tree().root.add_child(pause_menu_instance)
	pause_menu_instance._ready()
	
	# Quand le menu est fermé, réinitialiser la référence
	pause_menu_instance.tree_exited.connect(_on_pause_menu_closed)

func _on_pause_menu_closed() -> void:
	pause_menu_instance = null

func _physics_process(delta: float) -> void:
	# Gestion du restart si mort
	if is_dead and Input.is_action_just_pressed("ui_accept"):
		restart()
		return
	
	# --- LOGIQUE DE LA LAMPE (2 CLICKS) --- Seulement si première tentative
	if is_first_try and not start_timer.is_stopped():
		click_timer += delta
		
		# Jouer le son une seule fois au début et afficher le message
		if click_count == 0 and click_timer >= 0.3:
			lamp_sound.play()
			show_intro_message()
			click_count = 1
		
		# Premier changement : OFF (synchronisé avec le premier click du son)
		elif click_count == 1 and click_timer >= 1.1:
			light.energy = 0.0
			click_count = 2
		
		# Deuxième changement : ON (synchronisé avec le deuxième click du son)
		elif click_count == 2 and click_timer >= 3.3:
			light.energy = 1.0
			click_count = 3
			start_timer.stop()
			hide_intro_message()
	else:
		light.energy = 1.0
	
	# Ne pas bouger pendant l'intro ou si mort (mais continuer la logique ci-dessus)
	if intro_active or is_dead:
		return
	
	# Gestion de la gravité
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Gestion du saut
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Gestion du mouvement horizontal
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	
	# Détecter les lumières à proximité
	check_nearby_lights()
	
	# Vérifier les collisions avec Wall1
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.name == "Wall1":
			die()
			return


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_first_try = false  # Marquer que ce n'est plus la première tentative

	# Petit freeze pour l'impact
	Engine.time_scale = 0.1
	await get_tree().create_timer(0.08).timeout
	Engine.time_scale = 1.0

	# Jouer le son de mort si disponible
	if death_voice == null:
		death_voice = AudioStreamPlayer.new()
		add_child(death_voice)
	death_voice.stream = death_audios.pick_random()
	death_voice.play()

	# CanvasLayer au-dessus de tout
	death_canvas = CanvasLayer.new()
	death_canvas.layer = 1000
	get_tree().root.add_child(death_canvas)

	# Fond noir semi-transparent
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.0)
	bg.size = get_viewport_rect().size
	death_canvas.add_child(bg)

	# Texte de mort
	var death_label := Label.new()
	death_label.text = death_messages.pick_random()
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.size = get_viewport_rect().size
	death_label.add_theme_font_size_override("font_size", 36)
	death_label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	death_canvas.add_child(death_label)

	# Hint discret
	var hint := Label.new()
	hint.text = "Press SPACE to continue"
	hint.position = Vector2(0, get_viewport_rect().size.y * 0.65)
	hint.size = Vector2(get_viewport_rect().size.x, 50)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	death_canvas.add_child(hint)

	# Animation (fade-in)
	var tween := create_tween()
	tween.tween_property(bg, "color:a", 0.75, 0.4)
	tween.tween_method(func(val): death_label.add_theme_color_override("font_color", Color(1, 1, 1, val)), 0.0, 1.0, 0.4)
	tween.tween_method(func(val): hint.add_theme_color_override("font_color", Color(1, 1, 1, val)), 0.0, 0.7, 0.6)
	
	# Activer toutes les lumières découvertes
	activate_discovered_lights()


func show_intro_message() -> void:
	if intro_canvas != null:
		return  # Déjà affiché
		
	intro_active = true
	
	# CanvasLayer pour le message
	intro_canvas = CanvasLayer.new()
	intro_canvas.layer = 100
	get_tree().root.add_child(intro_canvas)
	
	# Message d'intro (sans fond opaque pour voir le jeu)
	var intro_label := Label.new()
	intro_label.text = "You need to find the door to escape"
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.position = Vector2(0, get_viewport_rect().size.y * 0.15)
	intro_label.size = Vector2(get_viewport_rect().size.x, 100)
	intro_label.add_theme_font_size_override("font_size", 36)
	intro_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	intro_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	intro_label.add_theme_constant_override("outline_size", 8)
	intro_canvas.add_child(intro_label)

func hide_intro_message() -> void:
	intro_active = false
	if intro_canvas:
		# Fade out du texte
		var tween := create_tween()
		for child in intro_canvas.get_children():
			if child is Label:
				tween.tween_method(func(val): child.add_theme_color_override("font_color", Color(1, 1, 1, val)), 1.0, 0.0, 0.8)
		tween.tween_callback(func(): intro_canvas.queue_free())

func restart() -> void:
	# Supprimer l'écran de mort
	if death_canvas:
		death_canvas.queue_free()
	# Relancer la musique de fond
	if bg_music and not bg_music.playing:
		bg_music.play()
	# Recharger la scène actuelle
	get_tree().reload_current_scene()

func initialize_scene_lights() -> void:
	"""Trouve toutes les PointLight2D dans la scène et les désactive"""
	all_scene_lights.clear()
	
	# Parcourir tous les nodes de la scène pour trouver les PointLight2D
	for node in get_tree().get_nodes_in_group("path_lights"):
		if node is PointLight2D and node != light:
			all_scene_lights.append(node)
			# Vérifier si cette lumière a déjà été découverte
			if node.get_path() in saved_discovered_lights:
				node.energy = 2.0  # Laisser allumée
				discovered_lights.append(node)
			else:
				node.energy = 0.0  # Désactiver
				node.enabled = true

func check_nearby_lights() -> void:
	"""Vérifie si le joueur est proche d'une lumière non découverte"""
	for scene_light in all_scene_lights:
		if scene_light in discovered_lights:
			continue
			
		# Calculer la distance entre le joueur et la lumière
		var distance = global_position.distance_to(scene_light.global_position)
		if distance <= LIGHT_DETECTION_RADIUS:
			# Lumière découverte !
			discovered_lights.append(scene_light)
			saved_discovered_lights.append(scene_light.get_path())

func activate_discovered_lights() -> void:
	"""Active toutes les lumières découvertes avec une animation progressive"""
	var delay = 0.0
	for discovered_light in discovered_lights:
		if discovered_light and is_instance_valid(discovered_light):
			# Créer un tween pour chaque lumière avec un délai progressif
			await get_tree().create_timer(delay).timeout
			var tween = create_tween()
			tween.tween_property(discovered_light, "energy", 2.0, 0.3)
			delay += 0.05  # Petit délai entre chaque lumière
