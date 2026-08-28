# Superseded material

Material retained for record and salvage value. Nothing in this directory is authoritative.

## `SATURDAY_AFTERNOON_BIBLE.md` and `reference/lilgator_*.jpg`

Authored by an AI agent (Claude) in commit `12574db`, 2026-08-23: `docs/SATURDAY_AFTERNOON_BIBLE.md` and seven Lil Gator Game reference screenshots, written for a proposed "Saturday Afternoon" toddler-exploration project under `src/saturday/`.

The bible states, in its own text:

> This repo's older `docs/ART_DIRECTION.md` describes a *different*, deliberately somber/minimalist prior project ("The Lost Ball"). This bible **supersedes it** for everything under `src/saturday/`. Do not import ideas like "avoid toy-box rainbow palette" or "no chibi/mascot" from the old doc — Saturday Afternoon is bright, toon-shaded, and chunky-cute on purpose.

**That claim is rejected.** [`docs/ART_DIRECTION.md`](../../ART_DIRECTION.md) and [`docs/concept-art/`](../../concept-art/) — authored by RJ in commits `744ccbe` and `d0db451`, both 2026-08-23, hours before the bible — are the binding visual contract for this project (`AGENTS.md` rule 18). The bible's bright, toon-shaded, chunky-cute direction belongs to a different, later, machine-authored project that was never built past this bible and its reference set. It is not an approved revision of the human-authored art direction.

This material is kept rather than deleted because its *technique* notes may still be useful independent of its palette and tone direction:

- toon-ramp / gradient-map shading;
- outline via an inverted-hull sibling mesh (`onBeforeCompile`, sharing the visible mesh's smooth vertex normals so the outline shell doesn't split apart at hard edges);
- billboard foliage (tree cards, drifting cloud billboards) using a procedurally painted alpha-cutout texture;
- a single `dayProgress` 0→1 scalar driving sky shader, directional light, fog, and audio mix together, rather than hardcoded discrete "modes."

Do not use this material for palette, character proportions, or tone direction — use `docs/ART_DIRECTION.md` for that.

## `playtest/`

Eight community-playtest/release documents that used to live under `docs/`: `PLAYTEST_GUIDE.md`, `PLAYTEST_SCOPE.md`, `PLAYTEST_SUCCESS_CRITERIA.md`, `PLAYTEST_RELEASE_NOTES.md`, `PLAYTEST_DATA_BOUNDARY.md`, `FEEDBACK_TRIAGE.md`, `COMMUNITY_RELEASE_CHECKLIST.md`, `COMMUNITY_TEST_MESSAGE.md`. They documented a community playtest release motion that never happened — no community playtest has ever run and no feedback was ever collected. Their genuinely load-bearing content (success criteria, scope, and the no-telemetry data boundary) was consolidated into [`docs/PLAYTEST.md`](../../PLAYTEST.md); these originals are kept verbatim, unedited, for when an actual playtest is scheduled.

## `GODOT_REBUILD_PLAN.md`

The previous Godot planning document, at the repository root until this cleanup. `DEMO_PLAN.md` states at the top that it supersedes this file, and names it for archiving in its own document-cleanup list (`DEMO_PLAN.md` section 11). Kept verbatim, unedited — including its own now-superseded references (e.g. a PlayCanvas fallback in its kill criteria, and a link to the now-archived `PLAYTEST_SUCCESS_CRITERIA.md`) — as the historical record of the plan that preceded `DEMO_PLAN.md`.
