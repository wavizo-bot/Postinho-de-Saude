extends Node
## Sons procedurais curtos, sem arquivos de audio. Cada evento empilha uma ou
## duas vozes e o mixer preenche o AudioStreamGenerator a cada quadro.

var player: AudioStreamPlayer
var gerador: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var vozes: Array = []
var volume := 0.26


func _exit_tree() -> void:
	vozes.clear()
	if player != null:
		player.stop()
	playback = null


func _ready() -> void:
	gerador = AudioStreamGenerator.new()
	gerador.mix_rate = 22050.0
	gerador.buffer_length = 0.18
	player = AudioStreamPlayer.new()
	player.stream = gerador
	player.volume_db = -7.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()
	set_process(true)


func tocar(nome: String) -> void:
	if player == null or playback == null:
		return
	match nome:
		"porta":
			_voz(150.0, 0.16, 0.30, 110.0, 0.0, 0.0)
			_voz(620.0, 0.045, 0.10, 420.0, 0.0, 0.02)
		"alerta":
			_voz(720.0, 0.11, 0.20, 760.0, 0.0, 0.0)
			_voz(940.0, 0.12, 0.17, 980.0, 0.0, 0.10)
		"atendimento":
			_voz(660.0, 0.13, 0.18, 720.0, 0.0, 0.0)
			_voz(990.0, 0.18, 0.13, 1040.0, 0.0, 0.09)
		"reclamacao":
			_voz(155.0, 0.33, 0.16, 120.0, 0.0, 0.0, true)
			_voz(232.0, 0.24, 0.08, 190.0, 0.0, 0.03, true)
		"aceitar":
			_voz(523.0, 0.12, 0.16, 560.0, 0.0, 0.0)
			_voz(784.0, 0.20, 0.14, 820.0, 0.0, 0.09)
		"negar":
			_voz(330.0, 0.16, 0.14, 290.0, 0.0, 0.0)
			_voz(247.0, 0.22, 0.11, 215.0, 0.0, 0.10)
		"tarefa":
			_voz(1046.0, 0.075, 0.14, 1100.0, 0.0, 0.0)
		"cafe":
			_voz(392.0, 0.14, 0.13, 440.0, 0.0, 0.0)
			_voz(587.0, 0.22, 0.12, 660.0, 0.0, 0.10)
		"clique":
			_voz(640.0, 0.035, 0.075, 680.0, 0.0, 0.0)
		"papo":
			_voz(620.0, 0.07, 0.13, 670.0, 0.0, 0.0)
			_voz(830.0, 0.10, 0.11, 880.0, 0.0, 0.07)
		_:
			_voz(500.0, 0.06, 0.08, 520.0, 0.0, 0.0)


func _voz(freq: float, dur: float, vol: float, freq_fim: float = 0.0, atraso: float = 0.0, _ignorado: float = 0.0, quadrada: bool = false) -> void:
	vozes.append({
		"freq": maxf(30.0, freq),
		"freq_fim": maxf(30.0, freq_fim if freq_fim > 0.0 else freq),
		"dur": maxf(0.02, dur),
		"vol": vol,
		"t": -absf(atraso),
		"quadrada": quadrada,
	})
	while vozes.size() > 8:
		vozes.pop_front()


func _process(_delta: float) -> void:
	if playback == null:
		return
	var quadros := playback.get_frames_available()
	if quadros <= 0:
		return
	var taxa := gerador.mix_rate
	var dt := 1.0 / taxa
	var buffer := PackedVector2Array()
	buffer.resize(quadros)
	for i in quadros:
		var amostra := 0.0
		for v in vozes:
			if float(v.t) < 0.0:
				v.t = float(v.t) + dt
				continue
			if float(v.t) >= float(v.dur):
				continue
			var frac := float(v.t) / float(v.dur)
			var env := minf(1.0, frac / 0.08) * minf(1.0, (1.0 - frac) / 0.18)
			var f := lerpf(float(v.freq), float(v.freq_fim), frac)
			var onda := sin(TAU * f * float(v.t))
			if bool(v.quadrada):
				onda = 1.0 if onda >= 0.0 else -1.0
			amostra += onda * env * float(v.vol)
			v.t = float(v.t) + dt
		amostra = clampf(amostra * volume, -0.85, 0.85)
		buffer[i] = Vector2(amostra, amostra)
	playback.push_buffer(buffer)
	var vivas: Array = []
	for v in vozes:
		if float(v.t) < float(v.dur):
			vivas.append(v)
	vozes = vivas
