# 🐱 Farmeow — 냥이농장

> 낮에는 고양이들과 농사를 짓고, 밤에는 그 작물로 몰려오는 좀비 동물을 막는
> **2D 도트 농사 + 타워디펜스 + 로그라이크** PC 게임 (Godot 4, Steam 출시 목표)

원작 [냥이농장(meowfarm)](https://github.com/halfcodz/meowfarm)의 고양이·작물·좀비 도트와 밸런스 수치를 그대로 가져와
Godot 4로 다시 만들고, PC용 레벨 디자인과 로그라이크 요소를 더했습니다.

## 핵심

| | |
|---|---|
| 🌾 작물 14종 · 🫛 방어작물 12종 | 같은 밭을 놓고 "돈이냐 방어냐"를 매일 고른다 |
| 🐱 고양이 11직업 × 4등급 | 목숨 9개, 다 잃으면 무지개다리로 |
| 🧟 좀비 9종 + 보스 5종 | 비행 · 방패 · 땅굴 · 자폭 · 치유 · 벽 통과 |
| 📖 7장 캠페인 (60일) | 장마다 마지막 밤은 보스전, 이길 때까지 반복 |
| 🎴 축복 카드 26종 | 살아남은 새벽마다 3장 중 1장 (일반·희귀·영웅·전설) |
| 🎰 냥슬롯 · 입양 상자 · 대박 수확 · 황금 좀비 · 치명타 · 콤보 | 랜덤 보상의 손맛 |
| ♾️ 끝없는 밤 · 환생 | 엔딩 후 별사탕으로 영구 강화하며 다시 |

## 조작

| 입력 | 동작 |
|---|---|
| 좌클릭 | 심기 · 수확 · 개간 · 선택 |
| 우클릭 / Esc | 선택 취소 |
| 1~9 | 퀵바 |
| 휠 · +/- | 줌 (1x / 2x / 3x) |
| WASD · 방향키 · 휠 클릭 드래그 | 카메라 이동 (Home: 농장으로) |
| B / C / R | 상점 / 고양이 / 연구 |
| H · F · N | 전부 수확 · 밥 주기 · 밤 맞이 |
| Space · Z | 일시정지 · 배속 |

## 실행 / 빌드

1. [Godot 4.3](https://godotengine.org/download) 설치 후 이 폴더의 `project.godot`를 연다
2. F5로 실행
3. 내보내기: **프로젝트 → 내보내기** — Windows / macOS / Linux(Steam Deck) 프리셋이 들어 있음
   (처음 한 번 **편집기 → 내보내기 템플릿 관리**에서 템플릿을 내려받아야 함)

### 테스트 (헤드리스)

```bash
godot --headless --path . res://tests/balance_bot.tscn -- --days 30            # 밸런스 봇 (생존율)
godot --headless --path . res://tests/balance_bot.tscn -- --days 20 --policy idle
godot --headless --path . res://tests/smoke.tscn                               # UI·저장·도박 흐름
```

현재 측정치 (축복 카드 없이 그리디 봇): 능동 약 91~93% · 방치 75% · 느긋하게 100% · 고양이 지옥 58%

## 폴더

```
scripts/sim/       시뮬레이션 (sim.gd, perks.gd) — 화면과 분리된 순수 로직
scripts/world/     농장 월드 그리기 (카메라·이펙트)
scripts/ui/        HUD · 상점 · 축복 카드 · 냥슬롯
scripts/autoload/  데이터 · 소리 · 설정 · 저장
assets/data/       원작에서 내보낸 수치(JSON) + 장(챕터) 설계
assets/sprites/    원작 코드 도트를 PNG로 내보낸 것 (반투명 그림자 제거)
assets/free/       무료 에셋 (Kenney 외, CREDITS.md)
tools/             원작 → Godot 내보내기 스크립트, 효과음 합성 스크립트
docs/              레벨 디자인 문서
```

## 라이선스 / 크레딧

코드는 halfcodz 소유. 사용한 무료 에셋은 모두 상업적 이용이 가능한 CC0 / OFL이며 [CREDITS.md](CREDITS.md)에 정리했습니다.
