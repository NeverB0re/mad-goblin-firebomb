extends SceneTree
## 별 누적 테스트: 한 번 받은 별은 다시 도전해 못 받아도 남고, 저장했다 불러와도 남는다. 옛 저장(별 개수)도 읽는다.

var _failures := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS ", msg)
	else:
		_failures += 1
		print("  FAIL ", msg)


func _initialize() -> void:
	print("== 별 누적 테스트 ==")
	SaveData.path = "user://test_star.cfg"
	SaveData.star_bits = {}
	SaveData.best = {}
	var bits := SaveData.record_clear(5, 2, 1 | 2 | 4)
	_check(bits == 7 and SaveData.star_count(5) == 3, "세 별을 모두 받으면 3개")
	bits = SaveData.record_clear(6, 1, 1 | 4)
	_check(bits == 5, "보조 목표 별만 먼저 받으면 그 별이 남는다")
	bits = SaveData.record_clear(6, 0, 1 | 2)
	_check(bits == 7 and SaveData.star_count(6) == 3, "나중에 다른 별을 받으면 먼저 받은 별에 더해져 3개")
	bits = SaveData.record_clear(6, 0, 1)
	_check(bits == 7, "다시 도전해 별을 못 받아도 받아 둔 별은 그대로")
	SaveData._loaded = false
	SaveData.star_bits = {}
	SaveData.load_all()
	_check(int(SaveData.star_bits.get(6, 0)) == 7 and int(SaveData.star_bits.get(5, 0)) == 7, "저장했다 불러와도 별이 남는다")
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "stars", {3: 2})
	cfg.save("user://test_star.cfg")
	SaveData._loaded = false
	SaveData.star_bits = {}
	SaveData.load_all()
	_check(SaveData.star_count(3) == 2, "옛 저장(별 2개)은 2개로 읽는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_star.cfg"))
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
