extends NivelSlimes
## Nivel de jungla: define con cuántos slimes cuenta.

func _init() -> void:
	slimes_nivel = {
		SlimeCatalogo.Tipo.BASE: 16,
		SlimeCatalogo.Tipo.FUEGO: 2,
	}
