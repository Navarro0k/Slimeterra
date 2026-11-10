extends Control
## Tablero explicativo del nivel: navegación y control de lectura.

signal cerrada

@export_enum("parabola", "matrices") var modo_ecuacion: String = "parabola"

const TOTAL_PAGINAS: int = 4

@onready var _lbl_modo: Label = $Panel/Margen/Contenido/Cabecera/Modo
@onready var _lbl_pagina: Label = $Panel/Margen/Contenido/Cabecera/Pagina
@onready var _lbl_titulo: Label = $Panel/Margen/Contenido/Titulo
@onready var _lbl_subtitulo: Label = $Panel/Margen/Contenido/Subtitulo
@onready var _texto: RichTextLabel = $Panel/Margen/Contenido/Texto
@onready var _progreso: ProgressBar = $Panel/Margen/Contenido/Progreso
@onready var _btn_anterior: Button = $Panel/Margen/Contenido/Pie/BtnAnterior
@onready var _lbl_estado: Label = $Panel/Margen/Contenido/Pie/EstadoLectura
@onready var _btn_siguiente: Button = $Panel/Margen/Contenido/Pie/BtnSiguiente
@onready var _musica: AudioStreamPlayer = $Musica

var _contenido := CartillaContenido.new()

var _pagina: int = 0
var _leidas: Array[bool] = []
var _leyendo: bool = false
var _cargando_pagina: bool = false
var _version_pagina: int = 0
var _cerrando: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_contenido.modo_ecuacion = modo_ecuacion

	_leidas.resize(TOTAL_PAGINAS)
	_leidas.fill(false)

	_configurar_cabecera_modo()

	_texto.get_v_scroll_bar().value_changed.connect(_on_scroll)
	_texto.resized.connect(_comprobar_lectura)

	# Silenciar la música del nivel mientras se lee.
	_pausar_musica_nivel(true)
	if _musica.stream != null:
		_musica.finished.connect(_on_musica_terminada)
		_musica.play()

	_actualizar_pagina()


func _configurar_cabecera_modo() -> void:
	if _contenido.es_matrices():
		_lbl_modo.text = "NIVEL 2 · MATRICES"
		_lbl_modo.add_theme_color_override("font_color", HudTema.AZUL)
	else:
		_lbl_modo.text = "NIVEL 1 · PARÁBOLA"
		_lbl_modo.add_theme_color_override("font_color", HudTema.VERDE)


## Condiciones iniciales y parámetros físicos del disparo actual.
func set_model_values(pos: Vector2, vel: Vector2, gravedad: float, amortiguamiento: float) -> void:
	_contenido.poner_modelo(pos, vel, gravedad, amortiguamiento)
	if is_node_ready() and visible:
		_actualizar_pagina()


func _actualizar_pagina() -> void:
	if _texto == null:
		return

	_version_pagina += 1
	var version := _version_pagina
	_cargando_pagina = true
	_leyendo = _leidas[_pagina]

	_lbl_pagina.text = str(_pagina + 1) + " / " + str(TOTAL_PAGINAS)
	_lbl_titulo.text = _contenido.titulo(_pagina)
	_lbl_subtitulo.text = _contenido.subtitulo(_pagina)
	_progreso.max_value = TOTAL_PAGINAS
	_progreso.value = _pagina + 1
	_texto.text = _contenido.contenido(_pagina)

	_btn_anterior.disabled = _pagina == 0
	_btn_siguiente.text = (
		"COMENZAR NIVEL  →" if _pagina == TOTAL_PAGINAS - 1 else "SIGUIENTE  →"
	)
	_btn_siguiente.disabled = not _leyendo
	_actualizar_estado_lectura()

	# Esperar a que RichTextLabel calcule su altura antes de subir el scroll.
	await get_tree().process_frame
	if version != _version_pagina or not is_inside_tree():
		return
	_texto.scroll_to_line(0)
	var barra := _texto.get_v_scroll_bar()
	if barra != null:
		barra.value = barra.min_value
	await get_tree().process_frame
	if version != _version_pagina or not is_inside_tree():
		return
	_cargando_pagina = false
	_comprobar_lectura()


func _on_scroll(_valor: float) -> void:
	if _cargando_pagina:
		return
	_comprobar_lectura()


## Una página se considera leída cuando el texto llega a su final.
func _comprobar_lectura() -> void:
	if _texto == null or _cargando_pagina:
		return
	var barra := _texto.get_v_scroll_bar()
	if barra == null or barra.page <= 0.0 or barra.max_value <= 0.0:
		return
	var al_final := (
		barra.max_value <= barra.page + 1.0
		or barra.value >= barra.max_value - barra.page - 1.0
	)
	if not al_final:
		return

	_leidas[_pagina] = true
	_leyendo = true
	_btn_siguiente.disabled = false
	_actualizar_estado_lectura()


func _actualizar_estado_lectura() -> void:
	if _leyendo:
		_lbl_estado.text = "Página leída. Puedes continuar."
		_lbl_estado.modulate = HudTema.VERDE
	else:
		_lbl_estado.text = "Desplázate hasta el final del texto para continuar."
		_lbl_estado.modulate = HudTema.TINTA_SUAVE


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
