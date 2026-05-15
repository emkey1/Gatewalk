extends RefCounted
class_name AudioManager

const StableRng = preload("res://scripts/core/StableRng.gd")
const ENABLE_SFX: bool = false


static func setup_music(parent: Node3D, rng: StableRng) -> void:
	var dir := DirAccess.open("res://audio/music")
	if dir == null:
		setup_procedural_music(parent, rng)
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".ogg") or fname.ends_with(".mp3") or fname.ends_with(".wav"):
			files.append("res://audio/music/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	if files.is_empty():
		setup_procedural_music(parent, rng)
		return
	_setup_rotating_playlist(parent, files, rng)


static func _setup_rotating_playlist(parent: Node3D, files: Array[String], rng: StableRng) -> void:
	if parent == null or files.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.bus = "Music"
	player.volume_db = -14.0
	parent.add_child(player)

	var last_index: int = -1
	var play_next := func() -> void:
		if files.is_empty():
			return
		var idx: int = int(rng.next_u32() % files.size())
		if files.size() > 1 and idx == last_index:
			idx = (idx + 1 + int(rng.next_u32() % (files.size() - 1))) % files.size()
		last_index = idx
		var stream: AudioStream = load(files[idx]) as AudioStream
		if stream == null:
			return
		player.stream = stream
		player.play()

	player.finished.connect(func() -> void:
		play_next.call()
	)
	play_next.call()


static func generate_wav_stream(freqs: Array[float], duration: float, vol: float, loop_enabled: bool = true) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var fade: int = int(sample_rate * 0.02)
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var s: float = 0.0
		for f in freqs:
			s += sin(TAU * f * t)
		s /= float(freqs.size())
		var env: float = 1.0
		if i < fade:
			env = float(i) / float(fade)
		elif i > num_samples - fade:
			env = float(num_samples - i) / float(fade)
		s *= env * vol
		data.encode_s16(i * 2, int(clamp(s * 30000.0, -32768.0, 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = sample_rate
	if loop_enabled:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = num_samples
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


static func setup_moon_audio(parent: Node3D) -> void:
	if not ENABLE_SFX:
		return
	var p := AudioStreamPlayer.new()
	p.name = "MoonDrone"
	p.bus = "SFX"
	p.volume_db = -1.0
	p.stream = generate_wav_stream([55.0, 72.0, 88.0, 105.0, 220.0, 330.0, 440.0], 8.0, 0.50)
	parent.add_child(p)
	p.play()


static func setup_water_audio(parent: Node3D) -> void:
	if not ENABLE_SFX:
		return
	var p := AudioStreamPlayer.new()
	p.name = "WaterAmbient"
	p.bus = "SFX"
	p.volume_db = -3.0
	p.stream = generate_wav_stream([75.0, 92.0, 110.0, 220.0, 440.0, 660.0], 6.0, 0.50)
	parent.add_child(p)
	p.play()


static func setup_cave_player_audio(parent: Node3D) -> void:
	if not ENABLE_SFX:
		return
	var p := AudioStreamPlayer.new()
	p.name = "CaveAmbient"
	p.bus = "SFX"
	p.volume_db = -4.0
	p.stream = generate_wav_stream([65.0, 130.0, 260.0, 390.0], 6.0, 0.40)
	parent.add_child(p)
	p.play()


static func setup_arctic_audio(parent: Node3D) -> void:
	if not ENABLE_SFX:
		return
	var p := AudioStreamPlayer.new()
	p.name = "ArcticAmbient"
	p.bus = "SFX"
	p.volume_db = -6.0
	p.stream = generate_wav_stream([55.0, 110.0, 165.0, 220.0, 330.0, 440.0], 8.0, 0.30)
	parent.add_child(p)
	p.play()


static func add_gate_audio(gate: Node3D) -> void:
	if not ENABLE_SFX:
		return
	var p := AudioStreamPlayer3D.new()
	p.name = "GateHum"
	p.bus = "SFX"
	p.volume_db = -2.0
	p.max_distance = 100.0
	p.attenuation_model = 1
	p.position = Vector3(0.0, 2.0, 0.0)
	p.stream = generate_wav_stream([330.0, 440.0, 550.0], 4.0, 0.25)
	gate.add_child(p)
	p.call_deferred("play")


static func setup_procedural_music(parent: Node3D, rng: StableRng) -> void:
	var base: float = 110.0
	var shift: int = int(rng.next_u32() % 3)
	if shift == 1:
		base = 123.47
	elif shift == 2:
		base = 98.0
	var pad := AudioStreamPlayer.new()
	pad.name = "ProceduralSynthPad"
	pad.bus = "Music"
	pad.volume_db = -11.0
	pad.stream = generate_wav_stream(
		[
			base,
			base * 1.5,
			base * 2.0,
			base * 2.5,
			base * 3.0
		],
		10.0,
		0.42
	)
	parent.add_child(pad)
	pad.play()

	var arp := AudioStreamPlayer.new()
	arp.name = "ProceduralSynthArp"
	arp.bus = "Music"
	arp.volume_db = -15.0
	arp.stream = generate_wav_stream(
		[
			base * 2.0,
			base * 2.25,
			base * 3.0,
			base * 4.0
		],
		4.0,
		0.22
	)
	parent.add_child(arp)
	arp.play()


static func play_moon_pilgrim_fanfare(parent: Node3D) -> void:
	if not ENABLE_SFX:
		return
	if parent == null:
		return
	var fanfare := AudioStreamPlayer.new()
	fanfare.name = "MoonPilgrimFanfare"
	fanfare.bus = "SFX"
	fanfare.volume_db = -4.0
	fanfare.stream = generate_wav_stream([220.0, 330.0, 440.0, 660.0, 880.0], 3.5, 0.55, false)
	parent.add_child(fanfare)
	fanfare.play()
	fanfare.finished.connect(func() -> void:
		if is_instance_valid(fanfare):
			fanfare.queue_free()
	)
