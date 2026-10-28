class_name Unidades
extends RefCounted
## Conversión entre las unidades del motor (píxeles, eje Y hacia abajo) y las unidades
## físicas que se le muestran al jugador (metros, eje Y hacia arriba).
##
## La escala se eligió para que la gravedad del proyecto (980 px/s²) sea exactamente
## 9.8 m/s²: así los números que ve el jugador coinciden con los de los libros.
## Con esta escala 1 m = 100 px, un tile de 16 px mide 16 cm y el slime unos 12 cm.

const PX_POR_METRO := 100.0

## Longitud en píxeles -> metros.
static func m(px: float) -> float:
	return px / PX_POR_METRO

## Vector del motor (px, Y abajo) -> vector físico (m, Y arriba).
## Sirve para posiciones relativas, velocidades (px/s -> m/s) y aceleraciones.
static func vec(v_px: Vector2) -> Vector2:
	return Vector2(v_px.x, -v_px.y) / PX_POR_METRO

## Gravedad del proyecto en m/s².
static func gravedad() -> float:
	return m(ProjectSettings.get_setting("physics/2d/default_gravity"))

## Coeficiente de arrastre lineal k (1/s). No depende de la escala de longitudes.
static func arrastre() -> float:
	return ProjectSettings.get_setting("physics/2d/default_linear_damp")

## Ángulo de lanzamiento en grados, medido desde la horizontal y positivo hacia arriba.
static func angulo_grados(v_px: Vector2) -> float:
	return rad_to_deg(atan2(-v_px.y, absf(v_px.x)))

## Formatea un número con 2 decimales y signo menos tipográfico.
static func num(x: float, decimales: int = 2) -> String:
	var texto := ("%." + str(decimales) + "f") % absf(x)
	return ("−" if x < 0.0 and texto.to_float() != 0.0 else "") + texto
