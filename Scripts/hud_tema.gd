class_name HudTema
extends RefCounted
## Paleta de la cartilla (cuaderno de papel) y fábricas de estilos del HUD.

# Papel y tinta.
const PAPEL := Color(0.96, 0.92, 0.78)
const PAPEL_CLARO := Color(0.99, 0.96, 0.85)
const PAPEL_OSCURO := Color(0.87, 0.81, 0.64)
const PAPEL_APAGADO := Color(0.80, 0.74, 0.57)
const TINTA := Color(0.30, 0.20, 0.08)
const TINTA_FUERTE := Color(0.10, 0.06, 0.01)
const TINTA_SUAVE := Color(0.48, 0.30, 0.07)
const BORDE := Color(0.36, 0.27, 0.11)
const BORDE_OSCURO := Color(0.18, 0.11, 0.03)
const CREMA := Color(0.98, 0.94, 0.82)

# Interacción y estados.
const HOVER := Color(0.42, 0.28, 0.10)
const PRESSED := Color(0.20, 0.13, 0.04)
const DESHABILITADO := Color(0.74, 0.68, 0.53)
const DESHABILITADO_TEXTO := Color(0.45, 0.38, 0.28)
const SEPARADOR := Color(0.45, 0.33, 0.14, 0.45)
const PROGRESO_FONDO := Color(0.80, 0.74, 0.57)
const PROGRESO_RELLENO := Color(0.55, 0.32, 0.08)
const VERDE := Color(0.18, 0.34, 0.10)
const AZUL := Color(0.10, 0.30, 0.46)
const SOMBRA := Color(0, 0, 0, 0.45)


static func fuente_pixel() -> FontFile:
	return load("res://Assets/fonts/PressStart2P-Regular.ttf") as FontFile


static func estilo_panel(color: Color = PAPEL, borde: Color = BORDE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = borde
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.shadow_color = SOMBRA
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


## Etiqueta pequeña de papel para lecturas sueltas (ángulo, cronómetro).
static func estilo_chip() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPEL
	s.border_color = BORDE
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.shadow_color = SOMBRA
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 1)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s


## Botón de cuaderno: relleno plano y borde de tinta de 1 px.
static func estilo_boton(color: Color = TINTA, borde: Color = BORDE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = borde
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


static func estilo_slider_fondo() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PROGRESO_FONDO
	s.border_color = BORDE
	s.set_border_width_all(0)
	s.set_corner_radius_all(2)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s


static func estilo_slider_relleno() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PROGRESO_RELLENO
	s.set_corner_radius_all(2)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s


## Cuadrado pixelado para el agarre del slider, en tono oscuro de la cartilla.
static func icono_pixel(color: Color, tam: int = 7) -> ImageTexture:
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	for y in tam:
		for x in tam:
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func etiqueta(texto: String, fuente: FontFile, size: int = 9, color: Color = TINTA_FUERTE) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if fuente != null:
		l.add_theme_font_override("font", fuente)
	return l


static func panel_contenedor(parent: Control, nombre: String, pos: Vector2, tam: Vector2, color: Color = PAPEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = nombre
	p.position = pos
	p.size = tam
	p.custom_minimum_size = tam
	p.add_theme_stylebox_override("panel", estilo_panel(color))
	parent.add_child(p)
	return p
