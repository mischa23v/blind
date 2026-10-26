# Fixed waiter pair: both arms passed

The one authorized native pair ([run 40245895908](https://github.com/mischa23v/blind/actions/runs/40245895908)) built the pinned observed-failure source once with an isolated test copy. Candidate first and original second each passed all 17 tests, with no failures or skips, on separate freshly created boot-ready simulators. Exact mode proofs, unchanged binary/source checks and owned-device cleanup passed.

The candidate had 88 timely wait returns, with a maximum observed elapsed time of 0.193 seconds; no late observations or deadline wakes occurred. This was not a reproduced failing workload. Whole test-command durations include startup and infrastructure, not condition-publication latency. The original successful arm did not export its per-wait latency distribution.

There was **no differential failure**. This does not establish XCTest as the cause of prior runtime failures and does not justify adopting the candidate helper in ordinary tests. Host load, fixed order and cache effects remain confounders. The default helper and production priorities/timeouts are unchanged; original failures remain evidence. No further run is requested by this receipt.
