"""데모 맵 「잊힘의 숲」 생성기 → scripts/level/level_data.gd
좌표는 18px 타일 단위, y는 위에서 아래로.

구역
  A 깨어난 공터      0-34   이동·점프 / 루미 합류
  B 첫 오솔길       34-64   할퀴기 / 첫 사당
  C 늙은 나무       64-80   베릴 / 기억 1
  D 메아리 협곡     80-89   벽 점프로 오르기
  E 우듬지         89-136  파랑 깃털(이중 점프) / 추억의 할머니 / 기억 2
  F 가시덤불 내리막 136-153  바람 발톱(대시) / 사당
  G 망각의 둥지     153-190  보스 망각의 곰 / 기억 3 / 데모 끝
"""
import sys

W, H = 192, 42
g = [['.'] * W for _ in range(H)]


def rect(x0, y0, x1, y1, c='#'):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H:
                g[y][x] = c


def put(x, y, c):
    g[y][x] = c


# 바닥 아래는 모두 흙, 맨 아래는 가시(떨어지면 되돌아감)
FLOOR = 30
# 왼쪽 벽
rect(0, 0, 1, H - 1)
# A 공터
rect(2, FLOOR, 41, H - 1)
rect(14, FLOOR - 1, 17, FLOOR - 1)
rect(24, FLOOR - 2, 27, FLOOR - 1)
rect(28, FLOOR - 1, 29, FLOOR - 1)
put(5, FLOOR - 1, 'P')
put(9, FLOOR - 1, 'L')           # 루미 합류 연출
put(12, FLOOR - 2, 'k')          # 힌트: 이동
put(21, FLOOR - 2, 'j')          # 힌트: 점프
for x in (7, 19, 31, 36):
    put(x, FLOOR - 1, 'o')
# B 오솔길: 구덩이(가시) + 발판
rect(42, FLOOR + 4, 44, H - 1)
rect(42, FLOOR + 3, 44, FLOOR + 3, '^')
rect(45, FLOOR, 66, H - 1)
rect(41, FLOOR - 3, 43, FLOOR - 3, '=')
put(47, FLOOR - 2, 'x')          # 힌트: 할퀴기
put(53, FLOOR - 1, 'r')
put(59, FLOOR - 1, 'r')
put(62, FLOOR - 1, 'o')
put(64, FLOOR - 1, 'S')          # 사당 1
# C 늙은 나무
rect(67, FLOOR, 82, H - 1)
put(71, FLOOR - 1, 'T')          # 큰 나무
put(73, FLOOR - 1, 'N')          # 베릴
rect(76, FLOOR - 4, 79, FLOOR - 4, '=')
put(78, FLOOR - 5, '1')          # 기억 1
put(66, FLOOR - 1, 'o')
# D 메아리 협곡 (벽 점프)
rect(80, 6, 82, FLOOR - 1)       # 왼벽
rect(88, 14, 90, FLOOR - 1)      # 오른벽 (위쪽은 출구)
rect(83, FLOOR, 87, H - 1)
rect(87, 6, 90, 9)               # 출구 위 천장
rect(80, 3, 90, 5)               # 협곡 지붕
put(85, FLOOR - 1, 'w')          # 힌트: 벽 점프
rect(83, 24, 84, 24, '=')
rect(86, 19, 87, 19, '=')
put(85, 16, 'c')
for y in (26, 21, 17):
    put(85, y, 'o')
# E 우듬지 (윗길 y=13)
TOP = 13
rect(88, TOP, 101, TOP + 2)
rect(91, TOP + 3, 101, TOP + 6)
put(96, TOP - 1, 'D')            # 파랑 깃털 (이중 점프)
put(93, TOP - 1, 'h')
rect(108, TOP, 111, TOP + 2)     # 섬 1 (간격 6: 이중 점프)
put(110, TOP - 1, "o")
rect(116, TOP, 119, TOP + 2)     # 섬 2
put(117, TOP - 1, 'c')
rect(121, TOP - 6, 128, TOP - 5) # 높은 가지 (이중 점프로)
put(123, TOP - 7, 'G')           # 추억의 할머니 고양이
put(127, TOP - 7, '2')           # 기억 2
rect(122, TOP, 137, TOP + 2)
rect(124, TOP + 3, 137, TOP + 5)
put(130, TOP - 1, 'b')
put(134, TOP - 1, 'o')
put(113, TOP - 3, 'o')
put(104, TOP - 3, 'o')
# 우듬지 아래: 떨어지면 가시 → 직전 안전 위치로
rect(91, H - 2, 153, H - 1, '#')
rect(91, H - 3, 153, H - 3, '^')
# F 가시덤불 내리막
rect(138, 17, 141, 17, '=')
rect(142, 21, 145, 21, '=')
rect(146, 25, 148, 25, '=')
rect(138, FLOOR, 153, H - 4)
put(140, FLOOR - 1, 'A')         # 바람 발톱 (대시)
put(142, FLOOR - 2, 'd')         # 힌트: 대시
rect(146, FLOOR - 1, 150, FLOOR - 1, '^')   # 대시로 넘는 가시밭

put(152, FLOOR - 1, 'f')
put(153, FLOOR - 1, 'S')         # 사당 2
# G 망각의 둥지 (보스)
rect(154, FLOOR, 191, H - 1)
rect(189, 0, 191, FLOOR - 1)     # 오른벽
rect(156, 12, 191, 13)           # 천장
rect(162, FLOOR - 5, 165, FLOOR - 5, '=')
rect(178, FLOOR - 5, 181, FLOOR - 5, '=')
put(159, FLOOR - 1, 'B')         # 보스 시작 지점(들어오면 문이 닫힘)
put(181, FLOOR - 1, 'K')         # 보스 등장
put(172, FLOOR - 1, '3')         # 기억 3 (보스 후)
put(186, FLOOR - 1, 'E')         # 데모 끝

rows = [''.join(r) for r in g]
out = ['# 자동 생성: tools/make_level.py — 직접 고치지 말고 생성기를 고칠 것', 'class_name LevelData', '', 'const TILE := 18', 'const MAP := [']
for r in rows:
    out.append('\t"%s",' % r)
out.append(']')
open(sys.argv[1], 'w').write('\n'.join(out) + '\n')
print('\n'.join(r[:100] for r in rows[4:]))
