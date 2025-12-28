extends Area2D

# Script pour les collectibles qui augmentent la vision du joueur

func _ready() -> void:
	# Ajouter ce node au groupe "collectibles" pour que le joueur puisse le détecter
	add_to_group("collectibles")
	
	# S'assurer que le nom commence par "collectible"
	if not name.begins_with("collectible"):
		name = "collectible_" + name
