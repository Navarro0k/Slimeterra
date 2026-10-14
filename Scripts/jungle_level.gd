extends NivelSlimes
## Nivel de jungla: hereda toda la lógica de NivelSlimes (resortera, UI y cámara)
## y solo define con cuántos slimes cuenta.

func _init() -> void:
	slimes_nivel = {
		SlimeCatalogo.Tipo.BASE: 6,
		SlimeCatalogo.Tipo.FUEGO: 1,
	}
