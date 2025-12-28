extends Area2D

# Script pour les zones de mort (deathzone)

func _ready() -> void:
	# Ajouter ce node au groupe "deathzones" pour que le joueur puisse le détecter
	add_to_group("deathzones")
