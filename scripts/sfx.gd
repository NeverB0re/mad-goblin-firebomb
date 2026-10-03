class_name Sfx
extends RefCounted
## 임시 효과음 세 가지(투척, 깨짐, 붕괴)를 코드로 합성한다.

const RATE := 22050
static var _cache := {}


static func _make(kind: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var dur := 0.35
	match kind:
		"throw": dur = 0.35
		"break": dur = 0.45
		"collapse": dur = 1.4
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var s := 0.0
		match kind:
			"throw":
				# 바람 가르는 소리: 대역 잡음, 올라갔다 내려가는 엔벨로프
				lp += (noise - lp) * 0.25
				var env := sin(PI * t / dur)
				s = (noise - lp) * env * 0.5
			"break":
				# 유리 깨짐: 고역 잡음 + 높은 사인 조각
				lp += (noise - lp) * 0.6
				var env := exp(-t * 11.0)
				var ting := sin(TAU * 3100.0 * t) * exp(-t * 18.0) + sin(TAU * 4700.0 * t) * exp(-t * 25.0)
				s = ((noise - lp) * 0.9 + ting * 0.35) * env
				# 불 붙는 소리
				lp2 += (noise - lp2) * 0.08
				s += lp2 * 1.6 * exp(-t * 4.0) * (1.0 - exp(-t * 30.0))
			"collapse":
				# 낮은 굉음
				lp += (noise - lp) * 0.04
				lp2 += (lp - lp2) * 0.08
				var env := (1.0 - exp(-t * 40.0)) * exp(-t * 2.2)
				s = lp2 * 9.0 * env + sin(TAU * 48.0 * t) * 0.15 * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


static func stream(kind: String) -> AudioStreamWAV:
	if not _cache.has(kind):
		_cache[kind] = _make(kind)
	return _cache[kind]


static func play(parent: Node, kind: String, pos: Vector3, volume_db := 0.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(kind)
	p.volume_db = volume_db
	p.unit_size = 25.0
	p.max_distance = 400.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
