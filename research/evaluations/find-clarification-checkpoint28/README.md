# Checkpoint28: useful search clarification without invented possession

The actual native checkpoint27 fridge test produced “Where did you last have it?” after “Help me find my fridge”. Passing state assertions did not make that a useful question.

Both unknown and unsuccessful-search branches now ask “Do you know which room or area to look in?” (Arabic: “هل تعرف في أي غرفة أو مكان نبحث؟”). Known clues still take priority. No fixed-object classifier, guessed room, camera claim or physical clearance was added. English historical rendering no longer converts “saw” or “was” into “last had”; Arabic recall also retains the stored uncertainty in past reported belief. Dates, sources, scopes and stored tense remain intact.

## Evidence cuts

- Before repair: 42 production-state tests, 18 failed assertions across five new episodes; original 37 tests passed.
- Frozen checkpoint27-plus-repair aggregate: 1,264 Core tests and 457 Swift-enabled serial Node checks, zero failures/skips. 987 source hashes stayed unchanged. The initial dataset-environment skip is disclosed in verification.json; the complete rerun supplied the pre-existing recorded trajectory.
- Later integration onto `550b845abce842719251017c3e3a09d8e95408d7`: diagnostic-only files overlaid; all production sources remained byte-identical to the aggregate candidate. The four CommunityTests wording assertions coexist with the seven existing model-status diagnostics. Thirty affected Node checks and ten exporter tests pass; three native test files pass syntax parsing, not Apple SDK typechecking. This is not a second full aggregate.
- Independent source review found no blocking issue for this bounded wording repair.

`verification.json` records only the seven source/test paths and hashes, not a complete workspace inventory. `selected-test-output.log` contains selected authored failure output and terminal summaries; absolute local paths were redacted explicitly. Complete original logs remain private.

## Still open

This does not locate the fridge, establish audible delivery or complete the user's goal. Natural short area answers currently route to ordinary model conversation; this is not proof that model-enabled handling fails, but an owned deterministic provisional-clue continuation is not implemented. Native three-turn and nonvisual task acceptance remain open. Existing report parsing can still turn the determiner “the” into “your”; this increment removes invented “last had”, not every ownership-naming issue. No safe independent or child use is established.
