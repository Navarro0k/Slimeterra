extends NivelSlimes
## Nivel de hielo: define con cuántos slimes cuenta.

func _init() -> void:
	slimes_nivel = {
		SlimeCatalogo.Tipo.BASE: 10,
		SlimeCatalogo.Tipo.FUEGO: 5,
	}
