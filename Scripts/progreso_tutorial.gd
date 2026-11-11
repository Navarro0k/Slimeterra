class_name ProgresoTutorial
extends RefCounted
## Persistencia de "explicación vista" por nivel (user://tutorial.cfg).

const RUTA := "user://tutorial.cfg"
const SECCION := "tutorial"


## true si la explicación de este nivel ya se cerró al menos una vez.
static func visto(ruta_nivel: String) -> bool:
	if ruta_nivel.is_empty():
		return false
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return false
	return bool(cfg.get_value(SECCION, _clave(ruta_nivel), false))


## Registra el nivel como visto. Si falla el guardado, solo avisa.
static func marcar_visto(ruta_nivel: String) -> void:
	if ruta_nivel.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.load(RUTA)
	cfg.set_value(SECCION, _clave(ruta_nivel), true)
	var error := cfg.save(RUTA)
	if error != OK:
		push_warning("No se pudo guardar el progreso del tutorial: %s" % error)


static func _clave(ruta_nivel: String) -> String:
	return ruta_nivel.md5_text()
