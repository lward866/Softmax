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
`player/player.bas` is an unmodified copy of the bundled **Baseline** player (draft missing roles,
farm lanes, last-hit, push exposed buildings and the god, level R/W/E/Q, cast spells, shop, buy back).
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
- `runs/local-smoke-001` (local, not committed): 5× Baseline (Red) vs 5× Rusher (Blue), seed 2026.
  Red won at tick 23548 (~16.4 min). Red scores 197/0/0/4953/220; Blue all 0.
