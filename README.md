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
- `runs/local-smoke-001` (local, not committed): 5× Baseline (Red) vs 5× Rusher (Blue), seed 2026.
  Red won at tick 23548 (~16.4 min). Red scores 197/0/0/4953/220; Blue all 0.
