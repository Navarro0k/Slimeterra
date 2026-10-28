class_name PanelTiro
extends CanvasLayer
## Panel de datos del tiro (esquina superior izquierda). Muestra, en metros y segundos, lo que
## RK4 predice mientras se apunta con la resortera: velocidad inicial, ángulo, componentes,
## altura máxima, alcance, tiempo de vuelo y el error frente a la solución exacta.
## Con la vista "RK4 por dentro" activa (tecla K) muestra además las pendientes k1..k4
## del paso seleccionado, con los mismos colores que las flechas dibujadas en el juego.
## Se construye por código: no necesita escena.

## Script de la resortera: de ahí salen los colores de k1..k4 para que coincidan con las flechas.
const Resortera := preload("res://Scripts/slingshoot.gd")

@export var tamano_fuente: int = 5
@export var ancho: float = 100.0

var _slingshot: Node
var _titulo: Label
var _texto: RichTextLabel
var _btn_rk4: Button
var _btn_plegar: Button
var _cuerpo: Control
var _ultimo: Dictionary = {}

func _ready() -> void:
	layer = 15
	_construir()
	_mostrar_vacio()

## Conecta el panel a la resortera del nivel.
func configurar(slingshot: Node) -> void:
	_slingshot = slingshot
	slingshot.prediccion_actualizada.connect(_on_prediccion)
	slingshot.tiro_disparado.connect(_on_tiro)
	slingshot.vista_rk4_cambiada.connect(_on_vista_rk4)
	_on_vista_rk4(slingshot.mostrar_rk4)

func _on_prediccion(datos: Dictionary) -> void:
	if datos.is_empty():
		if _ultimo.is_empty():
			_mostrar_vacio()
		return
	_titulo.text = "Predicción RK4 (apuntando)"
	_mostrar(datos)

func _on_tiro(datos: Dictionary) -> void:
	if datos.is_empty():
		return
	_ultimo = datos
	_titulo.text = "Último tiro (predicción RK4)"
	_mostrar(datos)

func _on_vista_rk4(visible_rk4: bool) -> void:
	_btn_rk4.text = "RK4 por dentro: %s  [K]" % ("sí" if visible_rk4 else "no")
	if not _ultimo.is_empty():
		var copia := _ultimo.duplicate()
		copia["rk4_visible"] = visible_rk4
		_mostrar(copia)

# ---------------------------------------------------------------------------
# Texto
# ---------------------------------------------------------------------------

func _mostrar_vacio() -> void:
	_titulo.text = "Datos del tiro"
	_texto.text = "Estira la resortera para ver\nlo que predice RK4."

func _mostrar(d: Dictionary) -> void:
	var v0: Vector2 = Unidades.vec(d["v0"])
	var pred: Dictionary = d["prediccion"]
	var lineas: PackedStringArray = []
	lineas.append("v₀ = %s m/s    θ = %d°" % [Unidades.num(v0.length()), roundi(Unidades.angulo_grados(d["v0"]))])
	lineas.append("vx = %s    vy = %s  m/s" % [Unidades.num(v0.x), Unidades.num(v0.y)])
	if pred["sube"]:
		lineas.append("Altura máx.: %s m" % Unidades.num(Unidades.m(pred["altura_max"])))
		if pred["completo"]:
			lineas.append("Alcance: %s m   Vuelo: %s s" % [
				Unidades.num(Unidades.m(pred["alcance"])), Unidades.num(pred["tiempo"])])
		else:
			lineas.append("Alcance: —   Vuelo: —")
	else:
		lineas.append("Tiro hacia abajo: no sube.")
	lineas.append("Error RK4 vs exacta: %s" % texto_error(d["error_px"]))
	lineas.append("[color=#aaaaaa]g = %s m/s²   k = %s s⁻¹[/color]" % [
		Unidades.num(Unidades.m(d["gravedad"])), Unidades.num(d["k"])])

	if d.get("rk4_visible", false):
		var e: Dictionary = d["etapas"]
		lineas.append("")
		lineas.append("[b]Paso %d de %d[/b]  (Δt = %s s)" % [d["paso_sel"] + 1, d["n"], Unidades.num(d["dt"])])
		var kp: Array = e["kp"]
		for i in 4:
			lineas.append("[color=#%s]k%d = %s m/s[/color]" % [
				_color_k(i).to_html(false), i + 1, par(Unidades.vec(kp[i]))])
		lineas.append("[color=#%s]prom. = %s m/s[/color]" % [
			_color_promedio().to_html(false), par(Unidades.vec(e["pendiente_p"]))])
		lineas.append("[color=#aaaaaa]Q / E o rueda: cambiar de paso[/color]")
	_texto.text = "\n".join(lineas)

## "(1.23, −4.56)"
static func par(v: Vector2) -> String:
	return "(%s, %s)" % [Unidades.num(v.x), Unidades.num(v.y)]

## El error de RK4 aquí es tan pequeño que queda por debajo de la precisión de los floats
## del motor; por debajo de 0.1 mm se muestra como cota en lugar de un número engañoso.
static func texto_error(error_px: float) -> String:
	var mm := Unidades.m(error_px) * 1000.0
	if mm < 0.1:
		return "< 0.1 mm"
	return "%s mm" % Unidades.num(mm, 1)

func _color_k(i: int) -> Color:
	return Resortera.COLORES_K[i]

func _color_promedio() -> Color:
	return Resortera.COLOR_PROMEDIO

# ---------------------------------------------------------------------------
# Construcción
# ---------------------------------------------------------------------------

func _construir() -> void:
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "top"]:
		margen.add_theme_constant_override("margin_" + lado, 3)
	add_child(margen)
	margen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.06, 0.1, 0.72)
	estilo.set_corner_radius_all(3)
	estilo.set_content_margin_all(3)
	panel.add_theme_stylebox_override("panel", estilo)
	margen.add_child(panel)

	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_theme_constant_override("separation", 2)
	panel.add_child(caja)

	var cabecera := HBoxContainer.new()
	cabecera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(cabecera)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", tamano_fuente + 1)
	_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(_titulo)

	_btn_plegar = _boton("–", _alternar_plegado)
	cabecera.add_child(_btn_plegar)

	var cuerpo := VBoxContainer.new()
	cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cuerpo.add_theme_constant_override("separation", 3)
	caja.add_child(cuerpo)
	_cuerpo = cuerpo

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.autowrap_mode = TextServer.AUTOWRAP_OFF
	_texto.custom_minimum_size = Vector2(ancho, 0)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_size_override("normal_font_size", tamano_fuente)
	_texto.add_theme_font_size_override("bold_font_size", tamano_fuente)
	_texto.add_theme_constant_override("line_separation", 0)
	cuerpo.add_child(_texto)

	_btn_rk4 = _boton("RK4 por dentro: no  [K]", func(): if _slingshot: _slingshot.alternar_rk4())
	cuerpo.add_child(_btn_rk4)

func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", tamano_fuente)
	b.pressed.connect(accion)
	return b

func _alternar_plegado() -> void:
	_cuerpo.visible = not _cuerpo.visible
	_btn_plegar.text = "–" if _cuerpo.visible else "+"
