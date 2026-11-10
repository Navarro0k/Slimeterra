extends Control
## Tablero explicativo del nivel: navegación, lectura y viñeta de apoyo.

signal cerrada

@export_enum("parabola", "matrices") var modo_ecuacion: String = "parabola"

const TOTAL_PAGINAS: int = 3

@onready var _lbl_modo: Label = $Panel/Margen/Contenido/Cabecera/Modo
@onready var _lbl_pagina: Label = $Panel/Margen/Contenido/Cabecera/Pagina
@onready var _cuerpo: HBoxContainer = $Panel/Margen/Contenido/Cuerpo
@onready var _lbl_titulo: Label = $Panel/Margen/Contenido/Cuerpo/Lectura/Titulo
@onready var _lbl_subtitulo: Label = $Panel/Margen/Contenido/Cuerpo/Lectura/Subtitulo
@onready var _texto: RichTextLabel = $Panel/Margen/Contenido/Cuerpo/Lectura/Texto
@onready var _vineta: VinetaDisparo = $Panel/Margen/Contenido/Cuerpo/Vineta/MargenVineta/ColumnaVineta/Lienzo
@onready var _leyenda: Label = $Panel/Margen/Contenido/Cuerpo/Vineta/MargenVineta/ColumnaVineta/Leyenda
@onready var _pips: HBoxContainer = $Panel/Margen/Contenido/Pips
@onready var _btn_anterior: Button = $Panel/Margen/Contenido/Pie/BtnAnterior
@onready var _lbl_estado: Label = $Panel/Margen/Contenido/Pie/EstadoLectura
@onready var _btn_siguiente: Button = $Panel/Margen/Contenido/Pie/BtnSiguiente
@onready var _musica: AudioStreamPlayer = $Musica

var _contenido := CartillaContenido.new()

var _pagina: int = 0
var _leidas: Array[bool] = []
var _version_pagina: int = 0
var _cerrando: bool = false

var _pips_nodos: Array[PanelContainer] = []
var _tween_pagina: Tween

var _modelo_pos: Vector2 = Vector2.ZERO
var _modelo_vel: Vector2 = Vector2.ZERO
var _modelo_gravedad: float = 980.0
var _modelo_amortiguamiento: float = 0.0
var _hay_modelo: bool = false

## Slime cargado en la resortera: la viñeta usa su mismo sprite.
var _textura_slime: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_contenido.modo_ecuacion = modo_ecuacion

	_leidas.resize(TOTAL_PAGINAS)
	_leidas.fill(false)

	_configurar_cabecera_modo()
	_construir_pips()
	_estilizar_scroll()

	# Silenciar la música del nivel mientras se lee.
	_pausar_musica_nivel(true)
	if _musica.stream != null:
		_musica.finished.connect(_on_musica_terminada)
		_musica.play()

	if _hay_modelo:
		_vineta.configurar(
			modo_ecuacion, _modelo_pos, _modelo_vel,
			_modelo_gravedad, _modelo_amortiguamiento
		)
	if _textura_slime != null:
		_vineta.set_textura_slime(_textura_slime)

	_actualizar_pagina()


func _configurar_cabecera_modo() -> void:
	if _contenido.es_matrices():
		_lbl_modo.text = "NIVEL 2 · TIRO CON AIRE"
		_lbl_modo.add_theme_color_override("font_color", HudTema.AZUL)
	else:
		_lbl_modo.text = "NIVEL 1 · TIRO IDEAL"
		_lbl_modo.add_theme_color_override("font_color", HudTema.VERDE)


## Condiciones iniciales y parámetros físicos del disparo preparado.
func set_model_values(pos: Vector2, vel: Vector2, gravedad: float, amortiguamiento: float) -> void:
	_modelo_pos = pos
	_modelo_vel = vel
	_modelo_gravedad = gravedad
	_modelo_amortiguamiento = amortiguamiento
	_hay_modelo = true
	_contenido.poner_modelo(pos, vel, gravedad, amortiguamiento)
	if not is_node_ready():
		return
	_vineta.configurar(modo_ecuacion, pos, vel, gravedad, amortiguamiento)
	if visible:
		_actualizar_pagina()


## La viñeta muestra el slime que el jugador tiene cargado.
func set_textura_slime(textura: Texture2D) -> void:
	if textura == null:
		return
	_textura_slime = textura
	if is_node_ready():
		_vineta.set_textura_slime(textura)


func _actualizar_pagina() -> void:
	if _texto == null:
		return

	_version_pagina += 1
	var version := _version_pagina
	# Basta con visitar la página para poder avanzar.
	_leidas[_pagina] = true

	_lbl_pagina.text = str(_pagina + 1) + " / " + str(TOTAL_PAGINAS)
	_lbl_titulo.text = _contenido.titulo(_pagina)
	_lbl_subtitulo.text = _contenido.subtitulo(_pagina)
	_texto.text = _contenido.contenido(_pagina)
	_leyenda.text = _contenido.etiqueta_vineta(_pagina)
	_vineta.set_pagina(_pagina)
	_actualizar_pips()

	_btn_anterior.disabled = _pagina == 0
	_btn_siguiente.text = (
		"COMENZAR NIVEL  →" if _pagina == TOTAL_PAGINAS - 1 else "SIGUIENTE  →"
	)
	_btn_siguiente.disabled = false
	_actualizar_estado_lectura()
	_animar_entrada_pagina()

	# Esperar a que RichTextLabel calcule su altura antes de subir el scroll.
	await get_tree().process_frame
	if version != _version_pagina or not is_inside_tree():
		return
	_texto.scroll_to_line(0)
	var barra := _texto.get_v_scroll_bar()
	if barra != null:
		barra.value = barra.min_value


func _construir_pips() -> void:
	for i in range(TOTAL_PAGINAS):
		var pip := PanelContainer.new()
		pip.name = "Paso%d" % (i + 1)
		pip.custom_minimum_size = Vector2(0, 4)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(pip)
		_pips_nodos.append(pip)


func _actualizar_pips() -> void:
	for i in range(_pips_nodos.size()):
		var activo := i == _pagina
		var visto := _leidas[i] and not activo
		_pips_nodos[i].add_theme_stylebox_override("panel", HudTema.estilo_pip(activo, visto))


func _estilizar_scroll() -> void:
	var barra := _texto.get_v_scroll_bar()
	if barra == null:
		return
	barra.custom_minimum_size = Vector2(4, 0)
	barra.add_theme_stylebox_override("scroll", HudTema.estilo_scroll_fondo())
	barra.add_theme_stylebox_override("scroll_focus", HudTema.estilo_scroll_fondo())
	barra.add_theme_stylebox_override("grabber", HudTema.estilo_scroll_agarre(HudTema.PAPEL_APAGADO))
	barra.add_theme_stylebox_override("grabber_highlight", HudTema.estilo_scroll_agarre(HudTema.TINTA_SUAVE))
	barra.add_theme_stylebox_override("grabber_pressed", HudTema.estilo_scroll_agarre(HudTema.TINTA))


func _animar_entrada_pagina() -> void:
	if _cuerpo == null:
		return
	if _tween_pagina != null and _tween_pagina.is_valid():
		_tween_pagina.kill()
	_cuerpo.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_tween_pagina = create_tween()
	_tween_pagina.tween_property(_cuerpo, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _actualizar_estado_lectura() -> void:
	if _pagina == TOTAL_PAGINAS - 1:
		_lbl_estado.text = "Revisa el resumen y pulsa COMENZAR NIVEL para jugar."
	else:
		_lbl_estado.text = "Página visitada. Pulsa SIGUIENTE para continuar."
	_lbl_estado.modulate = HudTema.VERDE


func _on_anterior() -> void:
	if _pagina <= 0:
		return
	_pagina -= 1
	_actualizar_pagina()


func _on_siguiente() -> void:
	if _cerrando or _btn_siguiente.disabled:
		return
	if _pagina < TOTAL_PAGINAS - 1:
		_pagina += 1
		_actualizar_pagina()
	else:
		_cerrar()


func _cerrar() -> void:
	if _cerrando or not _leidas[TOTAL_PAGINAS - 1]:
		return
	_cerrando = true
	_vineta.detener()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_musica.stop()
	_pausar_musica_nivel(false)
	cerrada.emit()
	queue_free()


func _pausar_musica_nivel(pausar: bool) -> void:
	for nodo in get_tree().get_nodes_in_group("musica_nivel"):
		if nodo is AudioStreamPlayer:
			(nodo as AudioStreamPlayer).stream_paused = pausar


func _on_musica_terminada() -> void:
	if not _cerrando and visible and _musica.stream != null:
		_musica.play()
