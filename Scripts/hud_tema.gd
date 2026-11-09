class_name HudTema
extends RefCounted
## Colores y fábricas de estilos/controles del HUD de disparo (ShotHUD).

const PANEL := Color("#17263B")
const PANEL_LIGHT := Color("#243B55")
const RED := Color("#62D9C7")
const TEXT := Color("#F0F6FF")
const EDGE := Color("#3C6680")


static func estilo_panel(color: Color = PANEL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = EDGE
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


## Panel sin fondo ni borde: solo se ve su contenido.
static func estilo_transparente() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(0, 0, 0, 0)
	s.set_border_width_all(0)
	s.set_corner_radius_all(0)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


static func estilo_boton(color: Color) -> StyleBoxFlat:
	var s := estilo_panel(color)
	s.border_color = color
	return s


static func etiqueta(texto: String, fuente: FontFile, size: int = 9, color: Color = RED) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	if fuente != null:
		l.add_theme_font_override("font", fuente)
	return l


static func panel_contenedor(parent: Control, nombre: String, pos: Vector2, tam: Vector2, color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = nombre
	p.position = pos
	p.size = tam
	p.custom_minimum_size = tam
	p.add_theme_stylebox_override("panel", estilo_panel(color))
	parent.add_child(p)
	return p
