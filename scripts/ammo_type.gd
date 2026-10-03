class_name AmmoType
extends Resource
## 탄종 데이터. 던지는 힘은 탄종마다 고정이며, 무게가 무거울수록 투척 속도가 느리다.

@export var display_name := "기본 화염병"
@export var weight := 1.0
## 투척 초기 속도 (m/s). 초기 속도 = throw_speed × 시선 방향.
@export var throw_speed := 40.0
## 깨질 때 블록 연결에 주는 충격 (거리 감쇠).
@export var impact_radius := 3.0
@export var impact_strength := 30.0
## 불웅덩이.
@export var pool_radius := 2.5
@export var pool_duration := 5.0
## 가연물을 약하게 만드는 속도 배수 (기름 단지용).
@export var burn_multiplier := 1.0
## 화염병 모델 크기 배수 (무게감 표현).
@export var model_scale := 1.0
