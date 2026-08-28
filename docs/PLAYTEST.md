# Playtest

## Status

No community playtest has run and no feedback has been collected. This document defines what a playtest of this project means — scope, success criteria, and the data rules that apply — so it isn't invented from scratch under time pressure once one is actually scheduled.

A larger, seven-document playtest apparatus used to live under `docs/` (a guide, tester messages, a release checklist, a feedback-triage guide) written for a community release motion that never happened. The genuinely load-bearing parts — success criteria, scope, and the data boundary — are consolidated below. The rest is archived at [`docs/archive/superseded/playtest/`](archive/superseded/playtest/).

## Scope

Whatever build is under test is one short episode, not the complete game. Today that means **The Lost Ball**: a compact courtyard-and-playground loop covering observe → retrieve → return → join → go-home, one Emotional Lens arc, child-height camera and movement, subtitles, a sound toggle, reduced motion, restart, and a local feedback export.

Not included, in either build:

- full-week progression;
- character customization;
- final art, animation, or voice acting;
- mobile controls, gamepad support, accounts, multiplayer, cloud saves, analytics, or telemetry;
- a production architecture beyond what `DEMO_PLAN.md` currently targets.

## Success criteria

The episode is successful enough to justify continued investment when most testers can:

1. start and finish without external instructions or debug controls;
2. understand the basic social situation before the ball escapes;
3. find the garden route without an arrow trail;
4. describe a change in mood or perception without being shown an emotion score;
5. interpret returning the ball as a social action, not only an item-delivery task;
6. identify at least one moment they would like the full game to explore further — for the current demo, that moment is meant to be the circle opening (`DEMO_PLAN.md` section 4).

The build is not successful merely because it runs, looks attractive, or receives polite comments.

## Data boundary

The build collects no telemetry and sends no player data automatically. Nothing leaves the browser (or, for the Godot build, the machine) without the tester actively choosing to do it.

Any end-of-session feedback form prepares a plain-text note locally; the tester decides whether to copy, download, or send it. Do not add analytics, session recording, fingerprinting, automatic feedback submission, account creation, or cloud storage under the label of playtest convenience, without an explicit product and privacy decision.

## When an actual playtest is scheduled

Revisit [`docs/archive/superseded/playtest/`](archive/superseded/playtest/) for the tester message, release checklist, and feedback-triage grouping — they were reasonable drafts, just written before there was anything ready to send anyone.
