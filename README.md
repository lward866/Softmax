# Gods of the Arena player

## Objective
Get a first working player into the Softmax **Gods of the Arena** league, then improve it
step by step using hosted Experience Requests (XP Requests). Beginner settings: deterministic
BASIC code, no LLM calls, small test batches, no league submission without the owner's OK.

## Target
- League: `league_3c60897b-25cf-4b37-9d1a-8554c1198f28` (Gods of the Arena) —
  https://softmax.com/observatory/v2?detail=league:league_3c60897b-25cf-4b37-9d1a-8554c1198f28
- Division: `div_a4534073-c5d2-4193-a94a-93d9c5e2e443` (Competition)
- Coworld: `cow_e282a46f-31c4-43b1-a9e2-aaa31d3aaed4` (Gods of the Arena, version 2026.9.24.2)
- Game README: `game.docs.readme` in the downloaded manifest; game docs:
  https://github.com/Metta-AI/polyworld/blob/main/examples/gods_of_the_arena/docs/index.html
- Runtime: `game-hosted` — the player is a single BASIC file, `player/player.bas`.

## Current strategy
`player/player.bas` (v8) is the bundled Baseline plus: positional play and pressure-based retreat (v5),
live lane buckets from allied buildings with least-crowded rotation (v7), and spell gates that keep E/R for
enemy heroes (v8), a fixed draft order led by the Druid Warden (v9), tower safety plus gear-first shopping (v11), spell timing (v12), and the soldier-wave wrapper with
ranged-first targeting and opening wave following (v14). It logs STATUS/POS/LANE/ACT/CAST notes every 30 s to the private player log.
Scoring is lifetime XP minus 200 per simulated minute, so faster wins score higher.

## Commands
```bash
uv sync
uv run coworld download cow_e282a46f-31c4-43b1-a9e2-aaa31d3aaed4   # needs Docker running
# Local smoke test (10 file paths, one per seat: 0-4 Red, 5-9 Blue)
P=player/player.bas; R=coworld/cow_e282a46f-31c4-43b1-a9e2-aaa31d3aaed4/player-files/9db9e5f1170347514bfdd3134f75e089d1f578e9567c4d516b1aaa14ef5b3c4d
uv run coworld run-episode ./coworld/cow_e282a46f-31c4-43b1-a9e2-aaa31d3aaed4/coworld_manifest.json \
  $P $P $P $P $P $R $R $R $R $R -o runs/local-smoke-001 --timeout-seconds 500
# Upload and hosted experience
uv run softmax login --no-browser
uv run coworld upload-policy --file player/player.bas
uv run coworld xp-request --help
```

## Results log
- Upload: `lward866-ply_fde93154-97b0-41bb-85d8-7152ad860c8c:v1` (tag version=baseline-v1).
- XP Request `xreq_d8772f1a-45d4-4136-9084-3e32cd1525fa` (`xp/xp-request-baseline-v1.json`): v1 vs 9 random league champions, rotate seats, 10 episodes.
  Result (all 10 hit the 20-min time limit, ~4,000 XP time penalty): v1 scored **0 in every match**.
  v1 averaged ~1,800 lifetime XP vs ~4,600 for the other 9 bots; it had the lowest XP on its team in 7/10.
  The league's own `Polyworld GOTA base.bas:v2` also averaged 0. Top random opponent: `khors:v208` (~5,300 avg score).
  Player logs contain only start/complete lines (the Baseline prints nothing); events.json was still pending.
- Upload v2 (`:v2`, tag version=baseline-v2-diagnostics): Baseline + STATUS prints, same behavior.
  XP Request `xreq_53bd9e1c-382e-470b-9fc6-2f5f9b65b285` (`xp/xp-request-v2-diagnostics.json`), same settings as v1.
  Result: score 0 in all 10; XP 1,407–3,778 (avg ~2,430) vs ~4,540 for others. Drafted Vanguard Knight in 7/10.
  Deaths 2–16. Main finding: `retreat=1` in ~35–45% of 30-second samples in 9/10 matches — the hero walks all the
  way back to spawn (~60–100 tiles) at 25% HP and waits for 90% HP, then walks back. E.g. seat 3: 2 deaths but only
  65 basic hits and level 6 after 20 minutes.
- Upload v3 (`:v3`, tag version=v3-tower-heal): heal at nearest allied tower with potions; buy 3 health potions first.
  XP Request `xreq_0e4c3c59-79a6-4d86-bd4a-b02bc545daae` (`xp/xp-request-v3-tower-heal.json`), same settings as v2.
  Result vs v2: **worse**. Avg XP 1,947 vs 2,431; deaths 9.2 vs 7.3; level 6.7 vs 7.6; retreat share 32% vs 36%.
  Logs show the hero often dying while retreating (hp=0 with retreat=1): lingering near the fight to drink potions
  gets it caught. Previous best remains v1/v2 behavior.
- Upload v4 (`:v4`, tag version=v4-offense-draft): v2 behavior + damage-first draft (Crossbowman, Death Knight, ...; Vanguard last).
  XP Request `xreq_4235ddc7-350b-43ca-ad04-eabfc8358b2c` (`xp/xp-request-v4-offense-draft.json`), same settings.
  Result vs v2: **not better**. Avg XP 2,052 vs 2,431; deaths 6.2 vs 7.3; level 6.9 vs 7.6; avg XP rank 8.4 vs 8.1.
  Drafted Death Knight 5, Crossbowman 4, Vanguard 1. Hero choice alone does not close the ~2,000 XP gap to other bots.
- Upload v5 (`:v5`, tag version=v5-positional): v2 + strategy-doc positional play (see `docs/`), POS/ACT notes.
  XP Request `xreq_7af8a557-6865-4931-bad5-e7afa2e2f92b` (`xp/xp-request-v5-positional.json`), same settings.
  Result vs v2: **best so far, modest**. Avg XP 2,701 vs 2,431 (+11%); deaths 5.8 vs 7.3; level 7.7 vs 7.6;
  avg XP rank 7.9 vs 8.1; score still 0 in all 10 (others avg ~4,650 XP). Drafted Vanguard 9/10.
  Activity (share of decisions): march 27% (22% following a wave), retreat 18%, fight creeps 13%, dead 9%,
  fight heroes 5%, buildings 1%, camps 1%. Position: middle lane 70% of samples, side lane A 25%, B 5%;
  median push depth -13 (own half); allied creeps within 6 tiles in 51% of samples; retreat reason mostly
  "enemy hero near at low HP" (54%) and "HP <= 20%" (27%).
- Upload v6 (`:v6`, tag version=v6-least-crowded-lane): v5 + least-crowded lane choice.
  XP Request `xreq_c26050a4-245a-47dd-8294-706ec2fd22b7` (`xp/xp-request-v6-lane.json`), same settings.
  Result vs v5: **best so far, small gain**. Avg XP 2,875 vs 2,701 (+6%; +18% vs v2); first non-zero score
  (327, Arcanist, 4,374 XP); avg XP rank 7.5 vs 7.9; level 8.1 vs 7.7. But deaths 7.7 vs 5.8 and dead time
  17% vs 9% of decisions (two Ranger games with 14-15 deaths). Lanes (new classifier): A 38%, M 30%, B 20%,
  base 10%, jungle 5%. Activity: march 29% (wave 14%), retreat 18%, dead 17%, creeps 12%, heroes 3%, camps 3%.
- Upload v7 (`:v7`, tag version=v7-live-lane-buckets): v5 + frame-spec lanes from live allied buildings (cached grid).
  XP Request `xreq_2df8e5ce-adb2-40c4-bb99-2a0d64636b17` (`xp/xp-request-v7-live-lanes.json`), same settings.
  Result vs v5: **pass on the spec's lane goals, XP flat**. Avg XP 2,749 vs 2,701 (v6 2,875); deaths 5.3 vs 5.8
  (v6 7.7); dead time 6% vs 9%; one non-zero score (290); zero BASIC errors. Lane time: A 56%, middle 11%, B 14%,
  base 19% (v5 middle ~70%). Rotations 0.2/match. Mean share 0.17, cover 0.46, attack lock 1.5 s.
  Allied creeps within 6 tiles 42% of samples (v5 49%).
- Upload v8 (`:v8`, tag version=v8-spell-gates): v7 + spell use card gates (see `docs/`).
  XP Request `xreq_143041d8-cf83-481d-b7a5-06547db57f0a` (`xp/xp-request-v8-spell-gates.json`), same settings.
  Result: **best so far**. Avg XP 3,123 vs 2,749 (v7) and 2,431 (v2); scores above 0 in 3/10 (736, 415, 31;
  avg 118); deaths 5.3 (= v7); level 8.5; avg XP rank 7.2; zero BASIC errors. Casts: E and R never on
  footmen/buildings (R hit heroes 45 times, E hit heroes 6 times, E self/ally heals 625); W 101 heroes / 423
  footmen. Lane time: A 57%, middle 7%, B 12%, base 24%.
- v8 confirmation: XP Request `xreq_c5582dc7-a8f9-4637-af96-de1bb399278a` (`xp/xp-request-v8-confirm-30.json`),
  30 more episodes, same settings. New 30: avg XP 2,900, 4/30 scores above 0. **All 40 v8 games: avg XP 2,956
  (95% margin ±298), median 2,818, scores above 0 in 7/40 (1,127, 736, 567, 415, 298, 144, 31), avg score 83,
  deaths 5.2, avg XP rank 7.5, zero BASIC errors.** Versus v2 (2,431 ±475, n=10) the gain looks real; versus v5
  (2,701) and v7 (2,749) it is within noise. By hero: Vanguard Knight 28 games avg 2,698; Druid Warden 6 games
  avg 3,876; Death Knight 3 games avg 3,065; Arcanist 1 game 5,143; Ranger 2 games avg 2,550.
- Upload v9 (`:v9`, tag version=v9-draft-order): v8 + fixed draft order (Druid, Death Knight, Arcanist,
  Crossbowman, Warlock, Berserker, Demon Hunter, Lich, Vanguard, Ranger).
  XP Request `xreq_837eb1e4-8d95-4ad6-94db-76296e67fef6` (`xp/xp-request-v9-draft-order.json`), 30 episodes.
  Result vs v8 (40 games): **clear improvement**. Avg XP 3,579 ±410 vs 2,956 ±298; median 3,651 vs 2,818;
  scores above 0 in 10/30 (best 1,881) vs 7/40; avg score 295 vs 83; avg XP rank 5.9 vs 7.5; deaths 5.6 vs 5.2;
  zero BASIC errors. Heroes: Druid 22 games avg 3,953; Death Knight 6 games avg 2,424; Vanguard 2 games avg 2,926.
- Upload v10 (`:v10`, tag version=v10-buildings): v9 + building card (structure target with footman cover).
  XP Request `xreq_4a7c1e49-2885-4d11-9bdc-6d961ba63daa` (`xp/xp-request-v10-buildings.json`), 30 episodes.
  Result vs v9: **not better**. Avg XP 3,521 ±390 vs 3,579 ±410; scores above 0 10/30 (same), avg score 268 vs
  295; deaths 6.7 vs 5.6; dead time 10.6% vs 8.2%; building time 1.6% vs 0.8%. A tower targeted the hero in 25%
  of decisions with an exposed structure in reach; cover only 33%. **One match lost the VM at ~12 min (BASIC
  instruction limit)** — the card's hard-fail condition. Druid 23 games avg 3,749 (v9 3,953).
  Inventory (per 30 s note): Ranger Boots almost always; Arcane Spellbook in ~22% of notes, Knight Armor ~5%.
  Previous best remains v9.
- Upload v11 (`:v11`, tag version=v11-tower-safety-shopping): v9 + tower safety (incl. protected towers) +
  gear-first shopping with safe shop trips and gear-reserving buyback.
  XP Request `xreq_c25cdae0-0c34-4b8c-999f-5bf3d433d221` (`xp/xp-request-v11-tower-shop.json`), 30 episodes.
  Result vs v9: **best so far**. Avg XP 3,968 ±489 vs 3,579 ±410; median 4,020 vs 3,651; scores above 0 in
  15/30 vs 10/30 (best 1,889); avg score 526 vs 295; deaths 4.1 vs 5.6; dead time 5.4% vs 8.2%; zero BASIC
  errors. Both gear pieces bought in 29/30 games (first piece at ~3.7 min median); 2.4 shop trips and 0.8
  buybacks per game. Druid 25 games avg 4,313 XP / 4.0 deaths; Death Knight 3 games avg 1,898.
- Upload v12 (`:v12`, tag version=v12-draft-spell-timing): v11 + Death Knight moved down the draft + spell timing.
  XP Request `xreq_c17a9ce8-4ac5-4286-9d67-3df4cc0039be` (`xp/xp-request-v12-draft-spells.json`), 30 episodes.
  Result vs v11: **no clear difference**. Avg XP 3,934 ±343 vs 3,968 ±489; median 4,088 vs 4,020; scores above 0
  in 18/30 vs 15/30 but avg score 332 vs 526 (fewer big games); deaths 4.5 vs 4.1; zero BASIC errors. Spells
  did what was intended: R on heroes 7.3/match vs 3.5, W on heroes 3.7 vs 1.9, E on heroes 1.5 vs 0.3. Arcanist
  was never drafted (taken first by others); second picks were Vanguard 3, Warlock 2, Berserker, Crossbowman,
  Death Knight 1 each. Druid 22 games avg 4,138.
- Upload v13 (`:v13`, tag version=v13-walk-notes): v12 behavior + WALK diagnostics note.
  XP Request `xreq_94fec0ca-04e0-43e5-b38d-4ca9eb3d2d5e` (`xp/xp-request-v13-walk-notes.json`), 30 episodes.
  Avg XP 3,531 ±360, scores above 0 in 7/30, avg score 226, deaths 5.1, zero errors. Same behavior as v12
  (3,934, 18/30), so **batch-to-batch noise at 30 games is roughly ±400 XP**.
  First 3 minutes: first contact with soldiers/targets at 43 s (median). Minute 0: 57% standing at the goal with
  nothing to hit, 34% walking. Minutes 1-2: ~42% fighting with no allied footman within 6 tiles (mostly enemy
  creeps), 11-22% retreating. March goal was the lane's front building 178/181 times — the lane grid is not
  ready early, so wave-following is effectively off in the opening. Committed lane B in 90% of samples.
- Upload v14 (`:v14`, tag version=v14-wave-wrapper): v13 + soldier-wave wrapper at own tower, ranged footmen first,
  opening lane split for wave following.
  XP Request `xreq_b4d73739-f971-4024-a7f7-1dd185c55d99` (`xp/xp-request-v14-wave-wrapper.json`), 30 episodes.
  Result vs v12+v13 combined (60 games, same behavior): **best so far, moderately confident**. Avg XP 4,016 ±367
  vs 3,733 ±252; scores above 0 in 15/30 (50%) vs 25/60 (42%); avg score 471 vs 279; deaths 4.2 vs 4.8; dead
  time 5.2% vs 6.6%; avg XP rank 5.7 vs 6.1; zero BASIC errors. First 3 minutes: walking far 6% (was 12%),
  idle at goal 16% (22%), fighting with soldiers 29% (24%), fighting alone 32% (30%), retreating 17% (11%).
- Upload v15 (`:v15`, tag version=v15-objective-notes): v14 behavior + OBJ note.
  XP Request `xreq_ed9454cb-913f-40a1-93dc-2de945d4567d` (`xp/xp-request-v15-obj-notes.json`), 30 episodes.
  Avg XP 3,892 ±365, scores above 0 15/30, avg score 350, deaths 4.7, zero errors. **v14+v15 (60 games, same
  behavior): avg XP 3,954 ±257, scores above 0 30/60, avg score 410, deaths 4.5, avg XP rank 5.7.**
  Objectives (decisions are 0.25 s): an attackable enemy tower is within 18 tiles only ~73 s per match; it is
  covered by our footmen 51% of that time; the push window (covered, enemy wave cleared) is ~17 s per match
  (median). In the window the hero hits a structure 62% and misses 35% (~6 s per match). An allied hero is at
  that tower 17% of the in-reach time. Matches split by hitting time: avg XP 3,540 / 3,929 / 4,208 (low→high).
- `runs/local-smoke-001` (local, not committed): 5× Baseline (Red) vs 5× Rusher (Blue), seed 2026.
  Red won at tick 23548 (~16.4 min). Red scores 197/0/0/4953/220; Blue all 0.
