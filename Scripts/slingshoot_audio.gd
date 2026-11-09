class_name SlingshootAudio
extends RefCounted
## Sonidos de la resortera: estirar (inicio + loop) y lanzar.

var _estirar: AudioStreamPlayer
var _estirar_loop: AudioStreamPlayer
var _lanzar: AudioStreamPlayer
var _inicio_sonado: bool = false
var _variacion_tono: float


func _init(padre: Node, bus_preferido: StringName, sonido_estirar: AudioStream, sonido_loop: AudioStream, sonido_lanzar: AudioStream, variacion_tono: float) -> void:
	_variacion_tono = variacion_tono
	var bus := bus_preferido if AudioServer.get_bus_index(bus_preferido) != -1 else &"Master"
	_estirar = _nuevo_reproductor(padre, sonido_estirar, bus)
	_estirar_loop = _nuevo_reproductor(padre, sonido_loop, bus)
	_lanzar = _nuevo_reproductor(padre, sonido_lanzar, bus)


## Sonido de inicio del estirón (solo la primera vez) y arranque del loop.
func iniciar_estirado(volumen_db: float, velocidad: float) -> void:
	if not _inicio_sonado:
		_inicio_sonado = true
		_reproducir(_estirar, volumen_db, velocidad)
	if not _estirar_loop.playing:
		_estirar_loop.play()


func detener_estirado() -> void:
	_estirar.stop()
	_estirar_loop.stop()
	_inicio_sonado = false


func lanzar(volumen_db: float, velocidad: float) -> void:
	_reproducir(_lanzar, volumen_db, velocidad)


func _nuevo_reproductor(padre: Node, stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = stream
	reproductor.bus = bus
	padre.add_child(reproductor)
	return reproductor


func _reproducir(reproductor: AudioStreamPlayer, volumen_db: float, velocidad: float) -> void:
	if reproductor and reproductor.stream:
		reproductor.volume_db = volumen_db
		reproductor.pitch_scale = velocidad * (1.0 + randf_range(-_variacion_tono, _variacion_tono))
		reproductor.play()
