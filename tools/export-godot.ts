/** meowfarm 데이터/스프라이트를 farmeow(Godot)용 PNG·JSON으로 내보낸다. */
import { mkdirSync, writeFileSync } from 'node:fs';
import { PixBuf } from '../src/render/pixbuf';
import { encodePng } from './png';
import { tileGrass, tileGravel, tileTilled, houseSprite, fencePiece, waterSparkle } from '../src/render/sprites/terrain';
import { buildCatFrames, FUR_SETS } from '../src/render/sprites/cat';
import { buildCropStages, buildCropIcon } from '../src/render/sprites/crop';
import { buildTurretFrames } from '../src/render/sprites/turret';
import { buildZombieFrames } from '../src/render/sprites/zombie';
import { CROPS } from '../src/data/crops';
import { DEFENSES } from '../src/data/defense';
import { JOBS, RARITIES, CAT_NAMES } from '../src/data/cats';
import { ZOMBIES } from '../src/data/zombies';
import { RESEARCH } from '../src/data/research';
import { planNight, baseHpForNight, nightDamageRef } from '../src/data/waves';
import { makeRng, deriveSeed } from '../src/sim/rng';

const OUT = process.argv[2]!;
const save = (rel: string, b: PixBuf) => {
  writeFileSync(`${OUT}/${rel}`, encodePng(b.w, b.h, b.data));
};
const strip = (frames: PixBuf[]): PixBuf => {
  const w = frames[0]!.w, h = frames[0]!.h;
  const s = new PixBuf(w * frames.length, h);
  frames.forEach((f, i) => s.blit(f, i * w, 0));
  return s;
};
for (const d of ['sprites/cats', 'sprites/crops', 'sprites/turrets', 'sprites/zombies', 'sprites/terrain', 'data']) {
  mkdirSync(`${OUT}/${d}`, { recursive: true });
}

// 고양이: 직업별 시트. 행 = 털색(6), 열 = idle0 idle1 walk0..3 act0 act1 down
for (const job of JOBS) {
  const rows = FUR_SETS.map((look) => {
    const f = buildCatFrames(look, job.id);
    return strip([...f.idle, ...f.walk, ...f.act, f.down]);
  });
  const sheet = new PixBuf(rows[0]!.w, rows[0]!.h * rows.length);
  rows.forEach((r, i) => sheet.blit(r, 0, i * r.h));
  save(`sprites/cats/${job.id}.png`, sheet);
}
for (const c of CROPS) {
  save(`sprites/crops/${c.id}.png`, strip(buildCropStages(c)));
  save(`sprites/crops/${c.id}_icon.png`, buildCropIcon(c));
}
for (const d of DEFENSES) {
  const f = buildTurretFrames(d);
  save(`sprites/turrets/${d.id}.png`, strip([...f.idle, f.fire, f.seedling, f.broken]));
}
for (const z of ZOMBIES) {
  const f = buildZombieFrames(z);
  save(`sprites/zombies/${z.id}.png`, strip([...f.walk, f.hit, ...f.die]));
}
save('sprites/terrain/grass.png', strip([0, 1, 2, 3].map(tileGrass)));
save('sprites/terrain/tilled.png', tileTilled(false));
save('sprites/terrain/watered.png', tileTilled(true));
save('sprites/terrain/gravel.png', tileGravel());
save('sprites/terrain/house.png', houseSprite());
save('sprites/terrain/fence_h.png', fencePiece('h'));
save('sprites/terrain/fence_v.png', fencePiece('v'));
save('sprites/terrain/fence_post.png', fencePiece('post'));
save('sprites/terrain/sparkle.png', waterSparkle());

const json = (rel: string, v: unknown) => writeFileSync(`${OUT}/${rel}`, JSON.stringify(v, null, 1));
json('data/crops.json', CROPS);
json('data/defenses.json', DEFENSES);
json('data/jobs.json', JOBS);
json('data/rarities.json', RARITIES);
json('data/cat_names.json', CAT_NAMES);
json('data/zombies.json', ZOMBIES);
json('data/research.json', RESEARCH);

// 밤 1~100: 고정 시드로 작곡된 웨이브 → 모든 플레이어가 같은 레벨을 만난다
const nights = [];
for (let n = 1; n <= 100; n++) {
  const p = planNight(n, makeRng(deriveSeed(20261126, n)));
  nights.push({
    night: n, duration: p.duration, boss: p.boss, newcomer: p.newcomer,
    totalHp: Math.round(p.totalHp), dmgRef: nightDamageRef(n), baseHp: baseHpForNight(n),
    threat: p.threat, waves: p.waves,
    spawns: p.spawns.map((s) => [Math.round(s.at * 100) / 100, s.dir, s.lane, s.type, s.hp]),
  });
}
json('data/nights.json', nights);
console.log('exported', OUT);
