# AGENTS.md

Guidance for coding agents working on this Gods of the Arena player.

## Sources of truth (read in order)
1. League participation guide:
   https://softmax.com/api/observatory/v2/participate?league_id=league_3c60897b-25cf-4b37-9d1a-8554c1198f28
   (a copy is in `Softmax - Gods of the Arena.docx`).
2. Coworld guide https://softmax.com/docs/coworld/overview and CLI map https://softmax.com/docs/coworld/cli;
   `uv run coworld --help`.
3. The game README at `game.docs.readme` in
   `coworld/cow_e282a46f-31c4-43b1-a9e2-aaa31d3aaed4/coworld_manifest.json` (download first).
- Forum: https://softmax.com/api/observatory/v2/forums/Gods%20of%20the%20Arena.md
- Wiki: https://softmax.com/api/observatory/v2/wikis/Gods%20of%20the%20Arena/pages.md

## Working agreement
- The owner is new to this; explain steps in plain language.
- Before editing the player: show replay/log evidence, name the clearest weakness, propose one
  targeted change, and ask for approval.
- Local episodes are smoke tests only. Judge strategy with hosted XP Request A/B batches, keeping
  opponent selection, rotate-seats, episode counts, and notes comparable between previous best and candidate.
- After each XP batch, compare candidate vs previous best in plain language.
- Never submit to the league unless the owner asks after A/B evidence shows a real improvement.
- When docs, commands, or behavior disagree, file an issue at https://github.com/Metta-AI/coworld/issues.

## Environment notes
- Docker may need starting in cloud containers: `dockerd &`.
- `run-episode` for this game-hosted Coworld needs exactly 10 `.bas` paths (one per seat).
