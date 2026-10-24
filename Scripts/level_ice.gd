extends NivelSlimes
## Nivel de hielo: hereda toda la lógica de NivelSlimes (resortera, UI y cámara)
## y solo define con cuántos slimes cuenta.

func _init() -> void:
	# Límites del nivel: calculados con los tiles sólidos (cámara limitada y rebote del slime).
	slimes_nivel = {
		SlimeCatalogo.Tipo.BASE: 10,
		SlimeCatalogo.Tipo.FUEGO: 5,
	}
