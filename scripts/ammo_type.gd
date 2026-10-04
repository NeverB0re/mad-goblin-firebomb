class_name AmmoType
extends Resource
## 탄종 데이터. 무게 변형이 아니라 역할이 다른 네 가지 (확장 기획서 5장).
## 던지는 힘은 탄종마다 고정이고, 궤적·폭발 반경·판정은 겉모습과 상관없이 항상 같다.

## FLAREGUN: 맞힌 지점을 후방 탄도미사일의 표적으로 지정한다 (4월드)
## STONE: 영점 돌. 화염탄과 무게·궤적이 같고 아무것도 부수지 않는다. 떨어진 자리에 흙먼지와 연기만 남긴다
enum Kind { FIRE, HE, OIL, FLARE, FLAREGUN, STONE }

@export var kind: Kind = Kind.FIRE
@export var display_name := "화염탄"
## 투척 초기 속도 (m/s). 초기 속도 = throw_speed × 시선 방향.
@export var throw_speed := 30.0
## 와인드업 최소 시간 (초, 물리 틱으로 환산해 센다). 무게를 먼저 몸으로 느끼게 한다.
@export var windup_time := 0.5
## 깨질 때 블록 연결에 주는 충격 (거리 감쇠). 0이면 충격 없음.
@export var impact_radius := 3.0
@export var impact_strength := 30.0
## 불웅덩이 (0이면 불 없음).
@export var pool_radius := 2.5
@export var pool_duration := 5.0
## 가연물을 약하게 만드는 속도 배수.
@export var burn_multiplier := 1.0
## 기름탄: 폭발 없이 퍼지는 기름 웅덩이 반경 (0이면 없음).
@export var oil_radius := 0.0
## 조명탄: 착탄 지점에서 솟아오르는 높이와 밝히는 시간 (0이면 없음).
@export var flare_height := 0.0
@export var flare_duration := 0.0
## 바람을 타는 정도 (가벼울수록 크다). 1 = 화염탄.
@export var wind_factor := 1.0
## 지휘관을 쓰러뜨리는 폭발 반경 (착탄점 기준). 0이면 직격만.
@export var kill_radius := 1.2
## 모델 크기 배수.
@export var model_scale := 1.0
