extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -500.0

@onready var light = $PointLight2D
@onready var start_timer = $Timer
@onready var animated_sprite = $Player  # Référence au sprite pour les animations
var click_count = 0
var click_timer = 0.0
var lamp_sound: AudioStreamPlayer = null
var is_dead = false
var death_canvas: CanvasLayer = null
var is_victorious = false  # Pour savoir si le joueur a gagné
var victory_canvas: CanvasLayer = null  # Canvas pour l'écran de victoire
var victory_countdown: float = 5.0  # Compte à rebours de 5 secondes
var victory_countdown_label: Label = null  # Label pour afficher le compte à rebours
var returning_to_menu = false  # Flag pour éviter les appels multiples

# Variables pour les collectibles et la vision
var base_light_scale: float = 1.5  # Échelle de base de la lumière
var light_scale_increment: float = 1  # Augmentation par collectible (plus visible)
var collectibles_count: int = 0

# Variables pour le système de lumières de chemin
var discovered_lights: Array[PointLight2D] = []  # Lumières découvertes par le joueur
static var saved_discovered_lights: Array[NodePath] = []  # Sauvegarder les chemins des lumières pour les respawns
const LIGHT_DETECTION_RADIUS = 150.0  # Rayon de détection des lumières
var all_scene_lights: Array[PointLight2D] = []  # Toutes les lumières de la scène
const PATH_LIGHT_RADIUS = 200.0  # Rayon d'influence des lumières de chemin sur la lumière du joueur
var target_player_light_energy: float = 1.0  # Énergie cible de la lumière du joueur
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
static var death_count: int = 0  # Compteur de morts du joueur (persiste entre reloads)
static var persistent_bg_music: AudioStreamPlayer = null  # Musique persistante entre les morts

var death_audios := [
	preload("res://audio/AudioD.ogg"),
]

# Son spécifique pour les morts causées par Wall1 (ne pas toucher `death_audios`)
var deathsound_file = preload("res://audio/deathsound.mp3")
var deathsound_player: AudioStreamPlayer = null
var trash1_file = preload("res://audio/trash1.mp3")

var background_music = preload("res://audio/dark-ambiant.mp3")
var lamp_sound_file = preload("res://audio/lamp.mp3")
var footstep_sound_file = preload("res://audio/footstep.mp3")
var start_sound_file = preload("res://audio/start.mp3")
var pause_menu_scene = preload("res://scenes/pause_menu.gd")
var jump_sound_file = preload("res://audio/jump.mp3")
var door_open_texture = preload("res://images/doorC.png")
var heartbeat_sound_file = preload("res://audio/hearth.mp3")
var pause_menu_instance = null
var footstep_player: AudioStreamPlayer = null
var jump_player: AudioStreamPlayer = null
var start_sound_player: AudioStreamPlayer = null
var start_sound_played: bool = false
var heartbeat_player: AudioStreamPlayer = null

# Flag pour éviter de rejouer le son de jump tant que le joueur n'a pas touché le sol
var can_play_jump: bool = true
var was_on_floor: bool = false

# Double jump
var max_jumps: int = 2
var jumps_done: int = 0

# Variable pour suivre la direction précédente du sprite
var last_flip_h: bool = false
var sprite_offset_x: float = 0.0  # Offset pour compenser le flip

# Variables pour le système de stress
var stress_level: float = 0.0  # Niveau de stress (0.0 à 100.0)
const STRESS_INCREASE_RATE: float = 12.0  # Stress gagné par seconde IMMOBILE (réduit de 20 à 12)
const STRESS_DECREASE_RATE: float = 25.0  # Stress perdu par seconde EN MOUVEMENT (inversé)
const STRESS_WARNING_THRESHOLD: float = 50.0  # Seuil pour afficher l'avertissement
const STRESS_DANGER_THRESHOLD: float = 75.0  # Seuil critique
const STRESS_MAX: float = 100.0  # Niveau maximum avant la mort
var stress_overlay: ColorRect = null  # Overlay rouge pour l'effet visuel
var stress_canvas: CanvasLayer = null  # Canvas pour l'overlay de stress
var heartbeat_timer: float = 0.0  # Timer pour l'effet de battement
var is_moving: bool = false  # Le joueur est-il en mouvement?
var stress_warning_shown: bool = false  # Avertissement affiché?
var stress_bar: ProgressBar = null  # Barre de progression pour le stress
var stress_label: Label = null  # Label pour afficher le pourcentage


func _ready() -> void:
	position = Vector2(50, 200)

	# Désactiver l'éclairage 2D sur le sprite du joueur pour éviter
	# qu'il prenne une teinte (jaune) quand d'autres PointLight2D s'allument.
	# On applique un shader simple non-éclairé (unshaded) à l'AnimatedSprite2D.
	if animated_sprite:
		var shader := Shader.new()
		# Rendre le shader non-éclairé pour qu'il ignore toutes les PointLight2D
		shader.code = "shader_type canvas_item;\nrender_mode unshaded;\nvoid fragment(){ COLOR = texture(TEXTURE, UV); }"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		animated_sprite.material = mat
		
		# Centrer le sprite pour éviter le décalage lors du flip
		animated_sprite.centered = true
		# Sauvegarder l'offset initial
		sprite_offset_x = animated_sprite.offset.x
	
	# Initialiser le son de lampe
	if lamp_sound == null:
		lamp_sound = AudioStreamPlayer.new()
		add_child(lamp_sound)
		lamp_sound.stream = lamp_sound_file

	# Initialiser le son des pas
	if footstep_player == null:
		footstep_player = AudioStreamPlayer.new()
		add_child(footstep_player)
		footstep_player.stream = footstep_sound_file
		# Si le flux le supporte, activer la boucle (utile si le fichier est un loopable sample)
		if footstep_player.stream:
			footstep_player.stream.loop = true

	# Initialiser le son de saut
	if jump_player == null:
		jump_player = AudioStreamPlayer.new()
		add_child(jump_player)
		jump_player.stream = jump_sound_file

	# Initialiser le son de battement de cœur
	if heartbeat_player == null:
		heartbeat_player = AudioStreamPlayer.new()
		add_child(heartbeat_player)
		heartbeat_player.stream = heartbeat_sound_file
		if heartbeat_player.stream:
			heartbeat_player.stream.loop = true
			print("✅ Son de battement de cœur chargé et configuré en boucle")
		else:
			print("❌ ERREUR : Impossible de charger hearth.mp3")
		heartbeat_player.volume_db = 5  # Volume augmenté (de -5 à 5)
	
	# Initialiser le lecteur dédié pour deathsound.mp3
	if deathsound_player == null:
		deathsound_player = AudioStreamPlayer.new()
		add_child(deathsound_player)
		deathsound_player.stream = deathsound_file

	# Initialiser le lecteur pour le son de démarrage (affiché avec le message d'intro)
	if start_sound_player == null:
		start_sound_player = AudioStreamPlayer.new()
		add_child(start_sound_player)
		start_sound_player.stream = start_sound_file
	
	# Initialiser la musique de fond - utiliser l'instance persistante si elle existe
	if persistent_bg_music == null:
		# Première fois, créer la musique
		persistent_bg_music = AudioStreamPlayer.new()
		# L'ajouter à la racine pour qu'elle persiste entre les rechargements de scène
		get_tree().root.add_child(persistent_bg_music)
		persistent_bg_music.stream = background_music
		persistent_bg_music.volume_db = 0 # Ajuster le volume si nécessaire
		if persistent_bg_music.stream:
			persistent_bg_music.stream.loop = true  # Activer la boucle
		persistent_bg_music.play()
	
	# Référencer la musique persistante
	bg_music = persistent_bg_music
	
	# Démarrer la lumière allumée et initialiser la séquence de clicks
	light.energy = 1.0
	click_count = 0
	click_timer = 0.0
	
	# Initialiser le système de lumières
	initialize_scene_lights()
	
	# Initialiser l'overlay de stress
	initialize_stress_overlay()
	
	# Si première tentative, démarrer les clignotements
	if is_first_try:
		start_timer.start(10.0)  # Démarrer le timer avec une longue durée pour la séquence
	else:
		# Sinon, lumière directement allumée sans clignotement
		light.energy = 1.0
	
	# Connecter les signaux pour les collectibles et deathzones
	setup_area_connections()

func setup_area_connections() -> void:
	"""Configure les connexions pour détecter les collectibles, deathzones et portes"""
	# Attendre un frame pour que tous les nodes soient chargés
	await get_tree().process_frame
	
	print("=== Début de la connexion des Area2D ===")
	
	# D'abord, connecter tous les collectibles du groupe
	for node in get_tree().get_nodes_in_group("collectibles"):
		if node is Area2D:
			if not node.body_entered.is_connected(_on_collectible_entered):
				node.body_entered.connect(_on_collectible_entered.bind(node))
				print("Collectible connecté (groupe) : ", node.name)
	
	# Ensuite, parcourir tous les Area2D de la scène pour les portes et deathzones
	for node in get_tree().get_root().find_children("*", "Area2D", true, false):
		if not node is Area2D:
			continue
		
		var node_name_lower = node.name.to_lower()
		
		# Vérifier la porte
		if "door" in node_name_lower:
			# Ajouter au groupe "door" pour faciliter la récupération
			if not node.is_in_group("door"):
				node.add_to_group("door")
			if not node.body_entered.is_connected(_on_door_entered):
				node.body_entered.connect(_on_door_entered.bind(node))
				print("Porte connectée : ", node.name)
		
		# Vérifier les deathzones (mais pas si c'est un collectible ou une porte)
		elif ("death" in node_name_lower or "trap" in node_name_lower) and not node_name_lower.begins_with("collectible"):
			if not node.body_entered.is_connected(_on_deathzone_entered):
				node.body_entered.connect(_on_deathzone_entered)
				print("Deathzone connectée : ", node.name)
	
	print("=== Fin de la connexion des Area2D ===")

func _on_collectible_entered(body: Node2D, collectible: Area2D) -> void:
	"""Appelé quand le joueur touche un collectible"""
	print("Collectible touché par : ", body.name)
	
	if body != self or not is_instance_valid(collectible):
		print("Ce n'est pas le joueur ou collectible invalide")
		return
	
	# Augmenter la zone de vision
	collectibles_count += 1
	var new_scale = base_light_scale + (light_scale_increment * collectibles_count)
	
	# Animer l'augmentation de la lumière
	var tween = create_tween()
	tween.tween_property(light, "texture_scale", new_scale, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Supprimer le collectible
	collectible.queue_free()
	
	print("Collectible récupéré ! Nouvelle zone de vision : ", new_scale)

func _on_deathzone_entered(body: Node2D) -> void:
	"""Appelé quand le joueur touche une deathzone"""
	if body != self:
		return
	
	# Jouer le son de mort spécifique
	if deathsound_player:
		deathsound_player.play()
	
	# Faire mourir le joueur
	die()

func _on_door_entered(body: Node2D, door_area: Area2D = null) -> void:
	"""Appelé quand le joueur atteint la porte (victoire)"""
	print("Porte touchée par : ", body.name)
	
	if body != self or is_victorious or is_dead:
		print("Ce n'est pas le joueur, déjà victorieux ou mort")
		return
	
	print("VICTOIRE !")
	
	# Changer la texture de la porte
	change_door_texture(door_area)
	
	is_victorious = true
	show_victory_screen()

func change_door_texture(door_area: Area2D) -> void:
	"""Change la texture de la porte en doorC.png"""
	print("=== Changement de texture de la porte ===")
	
	# Si la porte n'est pas passée, la chercher
	if door_area == null:
		print("Recherche de la porte...")
		door_area = get_tree().get_first_node_in_group("door")
		
		# Si pas trouvé par groupe, chercher dans toutes les Area2D
		if door_area == null:
			for node in get_tree().get_root().find_children("*", "Area2D", true, false):
				if "door" in node.name.to_lower():
					door_area = node
					print("Porte trouvée par nom : ", node.name)
					break
	
	if door_area == null:
		print("ERREUR : Porte non trouvée !")
		return
	
	print("Porte trouvée : ", door_area.name)
	print("Enfants de la porte : ", door_area.get_children())
	
	# Trouver le Sprite2D enfant de la porte
	for child in door_area.get_children():
		print("Enfant : ", child.name, " - Type : ", child.get_class())
		if child is Sprite2D:
			print("Sprite2D trouvé ! Changement de texture...")
			child.texture = door_open_texture
			print("Texture de la porte changée en doorC.png")
			return
	
	print("ERREUR : Sprite2D de la porte non trouvé !")

func show_victory_screen() -> void:
	"""Affiche l'écran de victoire"""
	# Allumer toutes les lumières encore désactivées avant de mettre en pause
	activate_all_remaining_lights()
	
	# Mettre le jeu en pause
	get_tree().paused = true
	
	# CanvasLayer au-dessus de tout
	victory_canvas = CanvasLayer.new()
	victory_canvas.layer = 1000
	victory_canvas.process_mode = Node.PROCESS_MODE_ALWAYS  # Continue de fonctionner même en pause
	get_tree().root.add_child(victory_canvas)
	
	# Fond noir semi-transparent
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.0)
	bg.size = get_viewport_rect().size
	victory_canvas.add_child(bg)
	
	# Texte de victoire
	var victory_label := Label.new()
	victory_label.text = "You escaped!"
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.size = get_viewport_rect().size
	victory_label.add_theme_font_size_override("font_size", 48)
	victory_label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	victory_canvas.add_child(victory_label)
	
	# Message secondaire
	var subtitle := Label.new()
	subtitle.text = "Congratulations!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, get_viewport_rect().size.y * 0.55)
	subtitle.size = Vector2(get_viewport_rect().size.x, 50)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	victory_canvas.add_child(subtitle)
	
	# Animation (fade-in) puis retour au menu
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Continue pendant la pause
	tween.tween_property(bg, "color:a", 0.8, 0.5)
	tween.tween_method(func(val): victory_label.add_theme_color_override("font_color", Color(1, 1, 1, val)), 0.0, 1.0, 0.5)
	tween.tween_method(func(val): subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, val)), 0.0, 1.0, 0.5)
	# Attendre un peu puis retourner au menu
	tween.tween_callback(return_to_menu).set_delay(1.5)

func _input(event: InputEvent) -> void:
	# Ouvrir le menu pause avec ESC
	if event.is_action_pressed("ui_cancel") and not is_dead and not is_victorious and pause_menu_instance == null:
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

func return_to_menu() -> void:
	"""Retourne au menu principal après la victoire"""
	print("Retour au menu demandé...")
	
	# Remettre le jeu en marche AVANT tout
	get_tree().paused = false
	
	# Arrêter la musique persistante si elle existe
	if persistent_bg_music and is_instance_valid(persistent_bg_music):
		persistent_bg_music.stop()
		persistent_bg_music.queue_free()
		persistent_bg_music = null
	
	# Réinitialiser les variables statiques
	reset_statics()
	
	# Nettoyer l'écran de victoire
	if victory_canvas and is_instance_valid(victory_canvas):
		victory_canvas.queue_free()
		victory_canvas = null
	
	# Utiliser call_deferred pour changer de scène après le frame actuel
	get_tree().call_deferred("change_scene_to_file", "res://scenes/menu.tscn")
	
	print("Changement de scène en cours...")

func _physics_process(delta: float) -> void:
	# Si victoire, ne pas traiter le reste
	if is_victorious:
		return
	
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
	
	# Ne pas bouger pendant l'intro ou si mort (mais continuer la logique ci-dessus)
	if intro_active or is_dead:
		return
	
	# Gestion de la gravité
	if not is_on_floor():
		velocity += get_gravity() * delta
		# Animation de saut en l'air
		if animated_sprite and animated_sprite is AnimatedSprite2D:
			animated_sprite.play("jump")
	
	# Gestion du saut (double jump)
	if Input.is_action_just_pressed("ui_up") and jumps_done < max_jumps:
		velocity.y = JUMP_VELOCITY
		jumps_done += 1
		# Jouer le son de saut à chaque saut (premier et second)
		if jump_player:
			jump_player.play()
	
	# Gestion du mouvement horizontal
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		
		# Retourner le sprite selon la direction en utilisant flip_h
		# et ajuster la position X pour compenser le décalage du sprite
		if animated_sprite:
			if direction < 0:
				animated_sprite.flip_h = true
				# Ajuster la position X pour compenser le décalage quand le sprite est flippé
				animated_sprite.position.x = -21  # Position inversée
			else:
				animated_sprite.flip_h = false
				# Position normale
				animated_sprite.position.x = 21
		
		# Animation de course si au sol
		if is_on_floor() and animated_sprite and animated_sprite is AnimatedSprite2D:
			animated_sprite.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		# Animation idle si au sol et immobile
		if is_on_floor() and animated_sprite and animated_sprite is AnimatedSprite2D:
			animated_sprite.play("idle")
	
	move_and_slide()

	# Détection d'atterrissage : remettre la possibilité de jouer le son de jump
	# et réinitialiser le compteur de sauts pour le double jump
	var landed = (not was_on_floor) and is_on_floor()
	if landed:
		can_play_jump = true
		jumps_done = 0
	was_on_floor = is_on_floor()

	# Jouer/arrêter le son des pas selon le mouvement horizontal sur le sol
	var walking = is_on_floor() and abs(velocity.x) > 10.0
	if footstep_player:
		if walking and not footstep_player.playing:
			footstep_player.play()
		elif (not walking and footstep_player.playing) or is_dead:
			footstep_player.stop()
	
	# Détecter les lumières à proximité
	check_nearby_lights()
	
	# Ajuster la lumière du joueur selon les zones éclairées
	adjust_player_light_in_lit_areas()
	
	# Gérer le système de stress
	update_stress_system(delta)
	
	# Vérifier les collisions avec Wall1
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.name == "Wall1":
			if deathsound_player:
				deathsound_player.play()
			die()
			return


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_first_try = false  # Marquer que ce n'est plus la première tentative

	# Incrémenter le compteur de morts (statique pour persister entre reloads)
	death_count += 1
	
	# Réinitialiser le stress
	stress_level = 0.0
	stress_warning_shown = false

	# Arrêter immédiatement le son des pas si en train de jouer (évite qu'il continue quand on reste appuyé)
	if footstep_player and footstep_player.playing:
		footstep_player.stop()
	
	# Arrêter le son de battement de cœur
	if heartbeat_player and heartbeat_player.playing:
		heartbeat_player.stop()
		print("🔇 Battement de cœur arrêté (mort)")

	# Petit freeze pour l'impact
	Engine.time_scale = 0.1
	await get_tree().create_timer(0.08).timeout
	Engine.time_scale = 1.0

	if death_voice == null:
		death_voice = AudioStreamPlayer.new()
		add_child(death_voice)
	# Si le joueur est mort plus d'une fois, utiliser trash1.mp3 au lieu du
	# son par défaut (AudioD.ogg dans death_audios)
	if death_count > 1 and trash1_file:
		death_voice.stream = trash1_file
	else:
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

	# Jouer le son de démarrage une seule fois (première tentative)
	if is_first_try and not start_sound_played and start_sound_player:
		start_sound_player.play()
		start_sound_played = true

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
	# La musique continue de jouer - pas besoin de la redémarrer
	# Elle persiste entre les rechargements de scène
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

func adjust_player_light_in_lit_areas() -> void:
	"""Ajuste la lumière du joueur en fonction des zones éclairées par les path_lights"""
	var in_lit_area = false
	
	# Vérifier si le joueur est dans une zone éclairée
	for scene_light in all_scene_lights:
		# Vérifier seulement les lumières allumées
		if scene_light.energy > 0:
			var distance = global_position.distance_to(scene_light.global_position)
			# Si le joueur est dans le rayon d'une lumière allumée
			if distance <= PATH_LIGHT_RADIUS:
				in_lit_area = true
				break
	
	# Ajuster l'énergie cible de la lumière du joueur
	if in_lit_area:
		target_player_light_energy = 0.0  # Éteindre la lumière dans les zones éclairées
	else:
		target_player_light_energy = 1.0  # Allumer dans le noir
	
	# Interpoler doucement vers l'énergie cible (sauf pendant l'intro avec les clignotements)
	if not (is_first_try and not start_timer.is_stopped()):
		light.energy = lerp(light.energy, target_player_light_energy, 0.1)

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

func activate_all_remaining_lights() -> void:
	"""Active toutes les lumières de la scène (découvertes ou non) lors de la victoire"""
	print("=== Activation de toutes les lumières pour la victoire ===")
	var light_count = 0
	
	# Parcourir toutes les lumières de la scène
	for scene_light in all_scene_lights:
		if scene_light and is_instance_valid(scene_light):
			# Allumer la lumière instantanément
			scene_light.energy = 2.0
			scene_light.enabled = true
			light_count += 1
			print("Lumière activée : ", scene_light.name)
	
	print("Total de ", light_count, " lumières activées")

func initialize_stress_overlay() -> void:
	"""Initialise l'overlay visuel pour le système de stress"""
	# Créer un CanvasLayer pour l'overlay
	stress_canvas = CanvasLayer.new()
	stress_canvas.layer = 500  # Au-dessus du jeu mais en dessous des menus
	add_child(stress_canvas)
	
	# Créer un ColorRect rouge semi-transparent
	stress_overlay = ColorRect.new()
	stress_overlay.color = Color(1, 0, 0, 0)  # Rouge transparent au départ
	stress_overlay.size = get_viewport_rect().size
	stress_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ne pas bloquer les inputs
	stress_canvas.add_child(stress_overlay)
	
	# Créer le conteneur pour le HUD de stress (en haut à gauche)
	var hud_container = VBoxContainer.new()
	hud_container.position = Vector2(20, 20)
	stress_canvas.add_child(hud_container)
	
	# Créer le label "STRESS"
	stress_label = Label.new()
	stress_label.text = "STRESS: 0%"
	stress_label.add_theme_font_size_override("font_size", 20)
	stress_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	stress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	stress_label.add_theme_constant_override("outline_size", 4)
	hud_container.add_child(stress_label)
	
	# Créer la barre de progression
	stress_bar = ProgressBar.new()
	stress_bar.min_value = 0
	stress_bar.max_value = 100
	stress_bar.value = 0
	stress_bar.custom_minimum_size = Vector2(200, 25)
	stress_bar.show_percentage = false
	
	# Style de la barre (via StyleBox)
	var stylebox_bg = StyleBoxFlat.new()
	stylebox_bg.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	stylebox_bg.border_width_left = 2
	stylebox_bg.border_width_right = 2
	stylebox_bg.border_width_top = 2
	stylebox_bg.border_width_bottom = 2
	stylebox_bg.border_color = Color(0, 0, 0, 1)
	stress_bar.add_theme_stylebox_override("background", stylebox_bg)
	
	var stylebox_fill = StyleBoxFlat.new()
	stylebox_fill.bg_color = Color(1, 0, 0, 0.8)
	stress_bar.add_theme_stylebox_override("fill", stylebox_fill)
	
	hud_container.add_child(stress_bar)
	
	print("Système de stress initialisé avec HUD")

func update_stress_system(delta: float) -> void:
	"""Met à jour le système de stress du joueur"""
	if is_dead or intro_active:
		return
	
	# Déterminer si le joueur est en mouvement (marche ou saute)
	is_moving = abs(velocity.x) > 10.0 or abs(velocity.y) > 10.0
	
	# INVERSÉ : Le stress augmente quand IMMOBILE, diminue quand EN MOUVEMENT
	if is_moving:
		# Le joueur bouge -> le stress diminue
		stress_level -= STRESS_DECREASE_RATE * delta
		stress_level = max(stress_level, 0.0)
	else:
		# Le joueur est immobile -> le stress augmente
		stress_level += STRESS_INCREASE_RATE * delta
		stress_level = min(stress_level, STRESS_MAX)
	
	# Mettre à jour le HUD
	update_stress_hud()
	
	# Vérifier si le joueur meurt de stress
	if stress_level >= STRESS_MAX:
		die_from_stress()
		return
	
	# Mettre à jour l'effet visuel
	update_stress_visual_effect(delta)
	
	# Afficher l'avertissement si nécessaire
	if stress_level >= STRESS_WARNING_THRESHOLD and not stress_warning_shown:
		show_stress_warning()
	elif stress_level < STRESS_WARNING_THRESHOLD and stress_warning_shown:
		stress_warning_shown = false

func update_stress_visual_effect(delta: float) -> void:
	"""Met à jour l'effet visuel de battement de cœur"""
	if stress_overlay == null:
		return
	
	# Calculer l'intensité de base selon le niveau de stress
	var base_intensity = 0.0
	var should_play_heartbeat = false
	
	if stress_level >= STRESS_DANGER_THRESHOLD:
		base_intensity = 0.4  # Rouge fort
		should_play_heartbeat = true
	elif stress_level >= STRESS_WARNING_THRESHOLD:
		base_intensity = 0.2  # Rouge moyen
		should_play_heartbeat = true
	else:
		base_intensity = 0.0  # Pas de rouge
		should_play_heartbeat = false
	
	# Effet de battement de cœur
	heartbeat_timer += delta
	var heartbeat_speed = 2.0  # Vitesse normale
	
	# Accélérer le battement quand le stress est élevé
	if stress_level >= STRESS_DANGER_THRESHOLD:
		heartbeat_speed = 4.0  # Battement rapide
	elif stress_level >= STRESS_WARNING_THRESHOLD:
		heartbeat_speed = 3.0  # Battement moyen
	
	# Créer un effet de pulsation avec sin
	var pulse = (sin(heartbeat_timer * heartbeat_speed * PI) + 1.0) / 2.0  # 0.0 à 1.0
	var final_intensity = base_intensity + (pulse * base_intensity * 0.5)
	
	# Appliquer la couleur
	stress_overlay.color.a = final_intensity
	
	# Gérer le son de battement de cœur - jouer seulement si l'écran est rouge
	if heartbeat_player and not is_dead:
		if should_play_heartbeat and base_intensity > 0:
			# L'écran est rouge, jouer le son s'il ne joue pas déjà
			if not heartbeat_player.playing:
				heartbeat_player.play()
				print("🔊 Battement de cœur activé - Stress: ", stress_level, "%")
			# Ajuster la vitesse de lecture selon le niveau de stress
			if stress_level >= STRESS_DANGER_THRESHOLD:
				heartbeat_player.pitch_scale = 1.3  # Plus rapide en zone danger
			else:
				heartbeat_player.pitch_scale = 1.0  # Vitesse normale en zone warning
		else:
			# L'écran n'est plus rouge, arrêter le son
			if heartbeat_player.playing:
				heartbeat_player.stop()
				print("🔇 Battement de cœur désactivé")


func update_stress_hud() -> void:
	"""Met à jour l'affichage du HUD de stress"""
	if stress_bar == null or stress_label == null:
		return
	
	# Mettre à jour la valeur de la barre
	stress_bar.value = stress_level
	
	# Mettre à jour le texte avec le pourcentage
	var stress_percent = int(stress_level)
	stress_label.text = "STRESS: " + str(stress_percent) + "%"
	
	# Changer la couleur du texte selon le niveau de stress
	if stress_level >= STRESS_DANGER_THRESHOLD:
		stress_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))  # Rouge vif
		# Changer aussi la couleur de la barre
		var stylebox_fill = StyleBoxFlat.new()
		stylebox_fill.bg_color = Color(1, 0, 0, 1)  # Rouge intense
		stress_bar.add_theme_stylebox_override("fill", stylebox_fill)
	elif stress_level >= STRESS_WARNING_THRESHOLD:
		stress_label.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))  # Orange
		# Changer la couleur de la barre
		var stylebox_fill = StyleBoxFlat.new()
		stylebox_fill.bg_color = Color(1, 0.5, 0, 0.9)  # Orange
		stress_bar.add_theme_stylebox_override("fill", stylebox_fill)
	else:
		stress_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))  # Blanc
		# Couleur normale de la barre
		var stylebox_fill = StyleBoxFlat.new()
		stylebox_fill.bg_color = Color(0.5, 1, 0.5, 0.8)  # Vert clair
		stress_bar.add_theme_stylebox_override("fill", stylebox_fill)

func show_stress_warning() -> void:
	"""Affiche un avertissement quand le stress devient élevé"""
	stress_warning_shown = true
	
	# Créer un label d'avertissement temporaire
	var warning_label = Label.new()
	warning_label.text = "Keep moving or you'll die!"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.position = Vector2(0, get_viewport_rect().size.y * 0.2)
	warning_label.size = Vector2(get_viewport_rect().size.x, 50)
	warning_label.add_theme_font_size_override("font_size", 28)
	warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 0))
	warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	warning_label.add_theme_constant_override("outline_size", 6)
	stress_canvas.add_child(warning_label)
	
	# Animer l'apparition et la disparition
	var tween = create_tween()
	tween.tween_method(func(val): warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, val)), 0.0, 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_method(func(val): warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, val)), 1.0, 0.0, 0.5)
	tween.tween_callback(func(): warning_label.queue_free())
	
	print("⚠️ Avertissement de stress affiché !")

func die_from_stress() -> void:
	"""Tue le joueur par excès de stress"""
	if is_dead:
		return
	
	print("💀 Mort par stress (immobilité) !")
	
	# Message spécifique pour la mort par stress
	var original_messages = death_messages
	death_messages = [
		"You stopped for too long.",
		"Stillness is death.",
		"Keep moving to survive.",
		"The darkness consumed you.",
		"Never stop moving."
	]
	
	# Appeler la fonction de mort normale
	die()
	
	# Restaurer les messages originaux pour les prochaines morts
	await get_tree().create_timer(0.1).timeout
	death_messages = original_messages



static func reset_statics() -> void:
	# Réinitialiser les variables statiques du player (utilisé par le menu restart)
	saved_discovered_lights = []
	is_first_try = true
