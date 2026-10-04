class_name Sfx
extends RefCounted
## 임시 효과음을 코드로 합성한다: 와인드업, 투척, 비행, 착탄(깨짐·고폭), 붕괴, 비명, 승리, 피식(강철에 꺼지는 불).
## 폭발음 아래에는 고무·징 소리를 한 겹 깔아 코믹하게 만든다.

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
		"windup": dur = 0.45
		"flight": dur = 1.2
		"boom": dur = 1.3
		"scream": dur = 1.6
		"win": dur = 1.2
		"fizzle": dur = 0.9
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
		match kind:
			"windup":
				# 숨 들이쉬기: 점점 커지는 부드러운 잡음
				lp += (noise - lp) * 0.12
				s = lp * 1.4 * (t / dur) * (1.0 - pow(t / dur, 6.0))
			"flight":
				# 병이 돌며 날아가는 휘파람 (점점 낮아짐)
				var f0 := 900.0 - 400.0 * t / dur
				s = sin(TAU * f0 * t + sin(TAU * 9.0 * t) * 2.0) * 0.18 * sin(PI * t / dur)
			"boom":
				# 묵직한 폭발 + 아래에 깔린 고무 "뽀잉"과 징 소리
				lp += (noise - lp) * 0.05
				lp2 += (lp - lp2) * 0.1
				var env := (1.0 - exp(-t * 60.0)) * exp(-t * 3.0)
				var boing := sin(TAU * (220.0 - 140.0 * t) * t + sin(TAU * 6.0 * t) * 3.0) * exp(-t * 3.5) * 0.22
				var gong := (sin(TAU * 196.0 * t) + sin(TAU * 293.0 * t) * 0.6) * exp(-t * 1.8) * 0.12
				s = lp2 * 10.0 * env + boing + gong
			"scream":
				# 길게 떨어지는 비명 (떨림 섞인 높은 음)
				var f1 := 1100.0 - 650.0 * t / dur + sin(TAU * 11.0 * t) * 60.0
				var env2 := minf(t * 20.0, 1.0) * (1.0 - t / dur)
				s = (sin(TAU * f1 * t) * 0.7 + sin(TAU * f1 * 2.0 * t) * 0.2) * env2 * 0.4
			"win":
				# 쾅 + 올라가는 징 화음
				var notes := [262.0, 330.0, 392.0, 523.0]
				var idx := mini(int(t / 0.12), 3)
				var nt := t - idx * 0.12
				s = sin(TAU * notes[idx] * t) * exp(-nt * 4.0) * 0.3 + noise * exp(-t * 20.0) * 0.5
			"fizzle":
				# 강철에 닿은 불이 피식 꺼지는 소리
				lp += (noise - lp) * 0.7
				s = (noise - lp) * 0.6 * exp(-t * 3.5)
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


## 먼 착탄은 소리가 늦게 도착한다 (음속 약 340m/s).
static func play_delayed(parent: Node, kind: String, pos: Vector3, volume_db: float, listener: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var delay := pos.distance_to(listener) / 340.0
	if delay < 0.03:
		play(parent, kind, pos, volume_db)
		return
	# 부모에 붙은 타이머라서 부모(스테이지)가 먼저 사라지면 함께 사라진다
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = delay
	timer.ignore_time_scale = true
	timer.autostart = true
	parent.add_child(timer)
	timer.timeout.connect(Sfx.play.bind(parent, kind, pos, volume_db))
	timer.timeout.connect(timer.queue_free)