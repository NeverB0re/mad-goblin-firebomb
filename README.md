# 화염병 투척 게임 프로토타입

Godot 4.7 / GDScript. 기획서: [docs/prototype_plan.md](docs/prototype_plan.md)

## 실행

- 에디터: `Godot_v4.7.2-stable_win64.exe`로 이 폴더의 `project.godot`를 열고 F5
- 바로 실행: `Godot_v4.7.2-stable_win64.exe --path .`
- 테스트: `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1`
  - `determinism_test`: 같은 위치·각도 20회 투척 착탄점 동일, 45도 사거리(기본 163m, 중량 118m)
  - `stage_test`: T1~T6를 계산된 투척으로 클리어 / 빗나가면 실패, 재시작 1초 이내
  - `screenshot.gd`(창 모드): 스테이지별 화면을 `tests/out`에 저장

## 조작

WASD 투척 구역 안 이동 · 마우스 시점(위아래 각도 = 투척 각도) · 좌클릭 즉시 투척 · 우클릭 유지 2배 줌 ·
1/2 또는 휠 탄종 교체 · R 재시작 · Enter 다음 스테이지(클리어 후) · F1~F6 스테이지 선택 · Esc 마우스 해제

## 구조

| 파일 | 역할 |
| --- | --- |
| `scripts/projectile.gd` | 고정 틱 직접 적분 + 구간 레이캐스트 투척체 (물리 엔진 미사용) |
| `ammo/*.tres` | 탄종 Resource (무게, 투척 속도, 충격, 불웅덩이) |
| `scripts/block.gd` / `structure.gd` | 블록(RigidBody3D, 평소 freeze)과 연결 강도, 받침 규칙, 붕괴, 연소 |
| `scripts/fire_pool.gd` | 불웅덩이: 가연물 점화 누적, 적 점화 |
| `scripts/enemy.gd` | Path3D 직선 경로를 일정 속도로 달아나는 적 |
| `scripts/stage.gd` / `stage_defs.gd` | 탄약, 판정, 테스트 스테이지 T1~T6 |
| `scripts/player.gd` / `hud.gd` / `main.gd` | 3인칭 플레이어, HUD, 입력과 스테이지 전환 |

## 기획서와 다르게 정한 점

- 시점은 요청에 따라 3인칭(어깨 너머).
- 코어 클리어: 땅에 닿거나, 잔해 위에서 멈췄을 때 처음 높이의 절반 이상(최소 2m) 떨어졌으면 인정.
  탑이 통째로 내려앉으면 코어가 잔해 더미 위(약 2.6m)에 남는 경우가 있어서다.
- 불웅덩이 범위 검사는 Area3D 대신 블록 표면까지의 거리로 직접 계산 (Jolt의 Area3D는 정지 물체 감지가 기본으로 꺼져 있음).
- 연소 직전 삐걱거리는 소리 대신 흔들림으로 표시 (사운드는 투척·깨짐·붕괴 3종만).
- 연습장(과녁판)은 아직 없음.