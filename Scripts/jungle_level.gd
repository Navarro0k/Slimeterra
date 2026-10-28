extends NivelSlimes
## Nivel de jungla: hereda toda la lógica de NivelSlimes (resortera, UI y cámara)
## y solo define con cuántos slimes cuenta.

func _init() -> void:
	id_teoria = "jungla"
	slimes_nivel = {
		SlimeCatalogo.Tipo.BASE: 16,
		SlimeCatalogo.Tipo.FUEGO: 2,
	}
#s
