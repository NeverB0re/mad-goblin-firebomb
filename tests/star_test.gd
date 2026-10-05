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
	# 새 저장은 잠겨 있고(1-1만), 전체 개방은 저장되며, 저장 지우기는 진행만 지운다
	SaveData._loaded = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_star.cfg"))
	SaveData.unlocked = 1
	SaveData.unlock_all = false
	SaveData.star_bits = {}
	SaveData.load_all()
	_check(not SaveData.unlock_all and SaveData.open_count() == 1, "처음에는 1-1만 열려 있다")
	SaveData.unlock_all = true
	SaveData.save_all()
	SaveData._loaded = false
	SaveData.unlock_all = false
	SaveData.load_all()
	_check(SaveData.unlock_all and SaveData.open_count() == Campaign.COUNT, "전체 개방을 켜면 저장되고 모든 진지가 열린다")
	SaveData.volume = 0.3
	SaveData.record_clear(0, 2, 7)
	SaveData.opening_seen = true
	SaveData.reset_progress()
	_check(SaveData.unlocked == 1 and SaveData.best.is_empty() and SaveData.star_bits.is_empty() and not SaveData.opening_seen and not SaveData.unlock_all and SaveData.open_count() == 1, "저장 지우기: 진행·별·오프닝·전체 개방이 처음으로")
	_check(is_equal_approx(SaveData.volume, 0.3), "저장 지우기는 음량 같은 설정은 남긴다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_star.cfg"))
	# 둘째 별은 쾅쾅알·불항아리가 남았을 때만: 4-1에서 번쩍봉만 남으면 못 받는다 (실패 판정에는 번쩍봉도 센다)
	var s := Stage.new()
	root.add_child(s)
	Campaign.build(30, s)
	for slot in s.ammo_slots:
		if slot.type.kind == AmmoType.Kind.HE or slot.type.kind == AmmoType.Kind.FLARE:
			slot.count = 1
	_check(Campaign.star_bits(30, s) & 2 != 0, "4-1 쾅쾅알이 남으면 둘째 별")
	for slot in s.ammo_slots:
		if slot.type.kind == AmmoType.Kind.HE:
			slot.count = 0
	_check(Campaign.star_bits(30, s) & 2 == 0 and s.total_ammo() > 0, "4-1 쾅쾅알을 다 쓰고 번쩍봉만 남으면 둘째 별 없음 (실패 판정에는 남은 탄 %d)" % s.total_ammo())
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
