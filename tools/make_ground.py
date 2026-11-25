"""Kenney Pixel Platformer 잔디/흙을 바탕으로 이음매 없는 땅 타일 12종을 만든다 → assets/tiles/ground.png
0 잔디(가운데) 1 잔디(왼끝) 2 잔디(오른끝) 3 잔디(외톨이)
4,5 흙 6 흙(왼쪽 가장자리) 7 흙(오른쪽) 8 흙(아래) 9 아래왼 10 아래오른 11 흙(점 많음)"""
from PIL import Image
import random
src = Image.open('assets/tiles/pp/tiles.png').convert('RGBA')
def tile(i): return src.crop(((i % 20) * 18, (i // 20) * 18, (i % 20) * 18 + 18, (i // 20) * 18 + 18))
t4 = tile(4)
px = t4.load()
base = px[9, 9]
# 점 색 모으기
cols = {}
for y in range(2, 16):
    for x in range(2, 16):
        c = px[x, y]
        if c != base and c[3] == 255: cols[c] = cols.get(c, 0) + 1
dots = sorted(cols, key=lambda c: -cols[c])[:3] or [(160, 90, 60, 255)]
OUT = (43, 39, 59, 255)
g2 = tile(2); g1 = tile(1); g3 = tile(3); g0 = tile(0)
# 잔디 높이: 흙 기본색이 처음 나오는 줄
gp = g2.load()
gh = 0
for y in range(18):
    if gp[9, y] == base: gh = y; break
if gh == 0: gh = 8
def dirt(seed, density=0.06):
    r = random.Random(seed)
    im = Image.new('RGBA', (18, 18), base)
    p = im.load()
    for y in range(18):
        for x in range(18):
            if r.random() < density: p[x, y] = dots[r.randrange(len(dots))]
    return im
def edge(im, l=False, rr=False, b=False):
    p = im.load()
    for y in range(18):
        if l: p[0, y] = OUT
        if rr: p[17, y] = OUT
    if b:
        for x in range(18): p[x, 17] = OUT
    return im
def grass(g, seed, l=False, rr=False):
    im = dirt(seed)
    im.paste(g.crop((0, 0, 18, gh + 2)), (0, 0))
    return edge(im, l, rr)
tiles = [grass(g2, 1), grass(g1, 2, l=True), grass(g3, 3, rr=True), grass(g0, 4, True, True),
         dirt(5), dirt(6), edge(dirt(7), l=True), edge(dirt(8), rr=True), edge(dirt(9), b=True),
         edge(dirt(10), l=True, b=True), edge(dirt(11), rr=True, b=True), dirt(12, 0.12)]
out = Image.new('RGBA', (18 * len(tiles), 18))
for k, t in enumerate(tiles): out.paste(t, (k * 18, 0))
out.save('assets/tiles/ground.png')
out.resize((out.width * 5, 90), Image.NEAREST).save('/tmp/ground_prev.png')
print('grass height', gh, 'dots', dots)
