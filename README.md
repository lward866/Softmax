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
- `runs/local-smoke-001` (local, not committed): 5× Baseline (Red) vs 5× Rusher (Blue), seed 2026.
  Red won at tick 23548 (~16.4 min). Red scores 197/0/0/4953/220; Blue all 0.
