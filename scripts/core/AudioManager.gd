extends RefCounted
class_name AudioManager

const StableRng = preload("res://scripts/core/StableRng.gd")


static func setup_music(parent: Node3D, rng: StableRng) -> void:
	var dir := DirAccess.open("res://audio/music")
	if dir == null:
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
		return
	var player := AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.stream = load(files[rng.next_u32() % files.size()])
	player.autoplay = true
	player.volume_db = -14.0
	parent.add_child(player)


static func generate_wav_stream(freqs: Array[float], duration: float, vol: float) -> AudioStreamWAV:
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
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


static func setup_moon_audio(parent: Node3D) -> void:
	var p := AudioStreamPlayer.new()
	p.name = "MoonDrone"
	p.volume_db = -2.0
	p.stream = generate_wav_stream([55.0, 72.0, 88.0, 105.0, 220.0, 330.0, 440.0], 8.0, 0.50)
	parent.add_child(p)
	p.play()


static func setup_water_audio(parent: Node3D) -> void:
	var p := AudioStreamPlayer.new()
	p.name = "WaterAmbient"
	p.volume_db = -3.0
	p.stream = generate_wav_stream([75.0, 92.0, 110.0, 220.0, 440.0, 660.0], 6.0, 0.50)
	parent.add_child(p)
	p.play()


static func add_gate_audio(gate: Node3D) -> void:
	var p := AudioStreamPlayer3D.new()
	p.name = "GateHum"
	p.volume_db = -2.0
	p.max_distance = 100.0
	p.attenuation_model = 1
	p.position = Vector3(0.0, 2.0, 0.0)
	p.stream = generate_wav_stream([330.0, 440.0, 550.0], 4.0, 0.25)
	gate.add_child(p)
	p.call_deferred("play")
