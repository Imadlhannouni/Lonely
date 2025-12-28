extends Area2D

# Script pour les zones de mort

func _ready() -> void:
	# Ajouter ce node au groupe "deathzones" pour que le joueur puisse le détecter
	add_to_group("deathzones")
	
	# S'assurer que le nom est "Deathzone"
	if name != "Deathzone":
		name = "Deathzone"
