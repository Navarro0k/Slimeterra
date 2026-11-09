class_name SlingshootBandas
extends RefCounted
## Dibuja las dos bandas elásticas de la resortera entre sus anclas y el holder.

var _izquierda: Line2D
var _derecha: Line2D
var _ancla_izquierda: Marker2D
var _ancla_derecha: Marker2D
var _centro: Marker2D


func _init(izquierda: Line2D, derecha: Line2D, ancla_izquierda: Marker2D, ancla_derecha: Marker2D, centro: Marker2D) -> void:
	_izquierda = izquierda
	_derecha = derecha
	_ancla_izquierda = ancla_izquierda
	_ancla_derecha = ancla_derecha
	_centro = centro


## Redibuja las bandas hacia `pos` (coordenadas locales de la resortera).
## Más estiradas = más delgadas y rectas; en reposo cuelgan con una curva.
func actualizar(pos: Vector2, max_stretch: float, grosor_reposo: float, grosor_estirado: float, caida_reposo: float) -> void:
	var tension: float = clampf(_centro.position.distance_to(pos) / max_stretch, 0.0, 1.0)
	var grosor: float = lerpf(grosor_reposo, grosor_estirado, tension)
	_izquierda.width = grosor
	_derecha.width = grosor
	_dibujar_curva(_izquierda, _ancla_izquierda.position, pos, tension, caida_reposo)
	_dibujar_curva(_derecha, _ancla_derecha.position, pos, tension, caida_reposo)


func mostrar(visible: bool) -> void:
	_izquierda.visible = visible
	_derecha.visible = visible


func _dibujar_curva(linea: Line2D, p_ini: Vector2, p_fin: Vector2, tension: float, caida_reposo: float) -> void:
	if tension > 0.05:
		linea.points = [p_ini, p_fin]
	else:
		var medio := p_ini.lerp(p_fin, 0.5)
		medio.y += lerpf(caida_reposo, 0.0, tension)
		linea.points = [p_ini, medio, p_fin]
