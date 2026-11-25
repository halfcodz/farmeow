class_name Perks
extends RefCounted
## 로그라이크 축복 카드. 생존한 새벽마다 3장 중 1장을 고른다. (환생하면 초기화)

const RARITY := [
	{"name": "일반", "color": Color("#c8c8d8"), "weight": 60},
	{"name": "희귀", "color": Color("#5aa9e6"), "weight": 28},
	{"name": "영웅", "color": Color("#b07aff"), "weight": 10},
	{"name": "전설", "color": Color("#ffcf4a"), "weight": 2},
]

## icon: [시트, 인덱스] — farm/town/battle/food
const LIST := [
	{"id": "grow", "r": 0, "max": 5, "name": "비옥한 땅", "desc": "성장 +12%", "icon": ["farm", 81]},
	{"id": "yield", "r": 0, "max": 5, "name": "알찬 이삭", "desc": "수확량 +10%", "icon": ["farm", 71]},
	{"id": "price", "r": 0, "max": 5, "name": "흥정의 달인", "desc": "판매가 +10%", "icon": ["town", 93]},
	{"id": "tdmg", "r": 0, "max": 5, "name": "가시 돋은 잎", "desc": "방어작물 공격 +12%", "icon": ["town", 118]},
	{"id": "trate", "r": 0, "max": 5, "name": "빠른 줄기", "desc": "발사 속도 +10%", "icon": ["town", 119]},
	{"id": "catatk", "r": 0, "max": 5, "name": "날 선 발톱", "desc": "고양이 공격 +15%", "icon": ["town", 129]},
	{"id": "cathp", "r": 0, "max": 5, "name": "통통한 뱃살", "desc": "고양이 체력 +15%", "icon": ["battle", 195]},
	{"id": "killcoin", "r": 0, "max": 5, "name": "현상금", "desc": "처치 코인 +25%", "icon": ["town", 93]},
	{"id": "house", "r": 0, "max": 5, "name": "튼튼한 지붕", "desc": "냥이집 체력 +20%", "icon": ["town", 128]},
	{"id": "seedluck", "r": 0, "max": 5, "name": "네잎클로버", "desc": "씨앗 드랍 +3%", "icon": ["farm", 9]},
	{"id": "crit", "r": 1, "max": 5, "name": "급소 찌르기", "desc": "치명타 확률 +6%", "icon": ["town", 95]},
	{"id": "critdmg", "r": 1, "max": 5, "name": "회심의 일격", "desc": "치명타 피해 +50%", "icon": ["town", 105]},
	{"id": "jackpot", "r": 1, "max": 5, "name": "대박 예감", "desc": "수확 대박 확률 +4%", "icon": ["farm", 66]},
	{"id": "range", "r": 1, "max": 3, "name": "멀리 뻗기", "desc": "사거리 +0.4칸", "icon": ["town", 118]},
	{"id": "frost", "r": 1, "max": 3, "name": "서리 맺힌 씨", "desc": "모든 공격 둔화 15%", "icon": ["food", "icecream_mint"]},
	{"id": "combo", "r": 1, "max": 3, "name": "연쇄 사냥", "desc": "콤보 코인 +50%", "icon": ["battle", 196]},
	{"id": "interest", "r": 1, "max": 3, "name": "돼지 저금통", "desc": "새벽 이자 +3%", "icon": ["farm", 125]},
	{"id": "boom", "r": 2, "max": 3, "name": "폭죽 좀비", "desc": "처치 시 20% 확률 폭발", "icon": ["town", 105]},
	{"id": "chain", "r": 2, "max": 3, "name": "번개 고양이", "desc": "치명타가 번개로 튄다", "icon": ["battle", 79]},
	{"id": "regrow", "r": 2, "max": 3, "name": "풍년", "desc": "수확 시 15% 즉시 재성장", "icon": ["farm", 78]},
	{"id": "ninelives", "r": 2, "max": 2, "name": "아홉 번째 목숨", "desc": "기절해도 30% 확률로 목숨 유지", "icon": ["battle", 195]},
	{"id": "lucky", "r": 2, "max": 3, "name": "행운의 고양이", "desc": "더 좋은 카드가 나온다", "icon": ["farm", 83]},
	{"id": "midas", "r": 3, "max": 2, "name": "미다스의 발", "desc": "모든 코인 +50%", "icon": ["food", "honey_pot"]},
	{"id": "goldrain", "r": 3, "max": 1, "name": "황금비", "desc": "매일 밤 황금 좀비 출현", "icon": ["town", 93]},
	{"id": "overclock", "r": 3, "max": 2, "name": "과열 모드", "desc": "발사 속도 +35%", "icon": ["town", 104]},
	{"id": "catgod", "r": 3, "max": 2, "name": "고양이 신", "desc": "고양이 전 능력 +40%", "icon": ["farm", 109]},
]


static func by_id(id: String) -> Dictionary:
	for p in LIST:
		if p.id == id: return p
	return {}


static func icon(p: Dictionary) -> Texture2D:
	var ic: Array = p.icon
	match ic[0]:
		"farm": return Data.farm_tile(ic[1])
		"town": return Data.town_tile(ic[1])
		"battle": return Data.battle_tile(ic[1])
		"food": return Data.food(ic[1])
	return null
