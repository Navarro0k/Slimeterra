class_name SlimeSonidos
extends RefCounted
## Sonidos puntuales del slime con reproductores temporales.


## Sonido al pegarse, con ligera variación de tono.
static func pegado(arbol: SceneTree, sonido: AudioStream, volumen_db: float, velocidad: float, variacion_tono: float, bus: StringName) -> void:
	var escena := arbol.current_scene
	if sonido == null or escena == null:
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = sonido
	reproductor.volume_db = volumen_db
	reproductor.pitch_scale = velocidad * (1.0 + randf_range(-variacion_tono, variacion_tono))
	reproductor.bus = bus if AudioServer.get_bus_index(bus) != -1 else &"Master"
	escena.add_child(reproductor)
	reproductor.finished.connect(reproductor.queue_free)
	reproductor.play()


## Sonido de quemado generado proceduralmente.
static func quemar(arbol: SceneTree) -> void:
	var escena := arbol.current_scene
	if escena == null:
		return
	var mix_rate := 22050.0
	var duracion := 0.25
	var generador := AudioStreamGenerator.new()
	generador.mix_rate = mix_rate
	generador.buffer_length = duracion
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = generador
	reproductor.volume_db = 2.0
	reproductor.bus = &"Master"
	escena.add_child(reproductor)
	reproductor.play()
	var playback := reproductor.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		playback.push_buffer(_generar_crash(mix_rate, duracion))
	arbol.create_timer(duracion + 0.1).timeout.connect(reproductor.queue_free)


static func _generar_crash(mix_rate: float, duracion: float) -> PackedVector2Array:
	var frames := int(mix_rate * duracion)
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	for i in range(frames):
		var t := float(i) / mix_rate
		var env := exp(-t * 18.0)
		var grave := sin(t * TAU * 55.0) * env * 0.6
		var medio := sin(t * TAU * 110.0) * env * 0.3
		var ruido := (randf() * 2.0 - 1.0) * env * env * 0.4
		var chasquido := 0.0
		if t < 0.005:
			chasquido = (randf() * 2.0 - 1.0) * (1.0 - t / 0.005) * 0.8
		var sample := clampf(grave + medio + ruido + chasquido, -1.0, 1.0)
		buffer[i] = Vector2(sample, sample)
	return buffer
