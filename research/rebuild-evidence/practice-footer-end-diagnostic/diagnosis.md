# Footer-end reachability diagnostic, no production change

Base63afd5d960f87ec63a109c1a70fc8bad9b4ec39b. Native run40209239473 on79f1b9d547030474142322856e8513b7fdbbc011 successfully executed both size probes (exit0), exported six exact authored screenshots, and uploaded artifact12605995482 (ZIP SHA2567e1b0d7fe24b15d336f36d28baf753eb010e70c6d890be9aee1949a6fa0cb24c). Actual PNGs were downloaded via the GitHub artifact connector and inspected.

Button height52→155.33pt, heading40.33→83.33pt, footer100.33→883.33pt from Large to accessibilityXXXL. The button visibly wraps to two complete lines. The heading visibly enlarges. The footer grows below the screen; its initialAXXXL framey466.67/maxY1350 extends beyond956pt window. The three role screenshots retain the same scroll position because hittable alone does not prove the paragraph's last line is visible. This is not proof of clipping or of an inaccessible footer end. Two endpoints do not demonstrate every supported size or disprove the earlier audit finding.

The separate unsuppressed audit did not execute: app launch timed out at LaunchTests.swift15. This run adds no new accessibility finding and is not an audit pass.

Proposed test-only increment preserves all three captures and adds footer-end per size. It scrolls within an8-up/8-down cap until the footer's bottom is between navigation-bar bottom and tab-bar top, then records a fourth screenshot and exact-label/hittability evidence. It does not require the entire tall paragraph to fit onscreen. The screenshot exporter requires all four named roles per size, eight total; required endpoint log must report endVisible=true. No existing audit or production file changed.

Ten parser fixture tests pass after the four-role change; helper bash syntax passes. Native compile, bottom reachability and actual end-warning pixels remain pending. No new font/style fix is proposed.
