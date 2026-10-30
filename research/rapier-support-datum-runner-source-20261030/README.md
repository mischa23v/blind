# Six-pose support-datum engine comparison — prepared, not run

Reuses the unchanged released Rapier comparator and original VTK body-contact
kernel. Both meshes retain exact prior Float32 bytes and original triangle order.
This is a bounded diagnostic of authored versus estimated foot placement,
not a path, route validator or geometry correction.

The six candidate datums were computed once by the separately published stdlib
materializer. All four nominal corners extrapolate the selected center triangle
at every pose. Nine sampled positions have eligible triangle hits, but they do
not establish continuous support or semantic floor. Conference has no original
floor component; Coffee's component is geometric only. The same estimated foot
is used for nominal and margin queries, without moving any actual user or mesh.

## Exact comparison

- 6 original probes, original/candidate foot Y, zero/original XYZ intent,
  nominal/margin envelopes = **48 KCC calls**. Stationary original intent remains
  zero, including duplicate conditions. No rotations or horizontal projection.
- Raw mesh flags only: the earlier 164 paired proposals did not differ by flags.
- The companion VTK kernel checks matching positions/translations with **no
  ground-face exemptions**, separately retaining full cuboid and lower2mm-trim
  cases: **96 envelope/band records**. Original high geometry remains present.
- Full contact IDs/heights are descriptive; near-foot is not semantic floor and
  a surface intersection is not automatically a physical obstacle. Native KCC
  computedGrounded and depenetration are not evidence of physical support.
- No controller proposal is applied. The two analytic down-step failures remain
  failed. This does not establish stair detection, arrival or route safety.

## Runtime contract

Only root may execute after publication and independent review. Existing managed
sandbox, one CPU, serial Node then Python, aggregate120 CPU seconds/180 wall
seconds/1GiB observed RSS/16MiB output. Node oldspace256MiB/semispace8MiB; no
RLIMIT_AS, new namespaces, host setting changes, network, installs or retries.
Node retains scoped reads/writes and no child/worker/native-addon permissions.
Python uses installed VTK/NumPy under isolated mode, explicit pinned adapters;
this is trusted-source execution, not a hostile-code airgap. Observed RSS polling
is not a hard cgroup limit. All partial failures remain saved; no thresholds or
poses are relaxed on failure.

Future command once exact source commit is admitted:

```
env -i PATH=/usr/bin:/bin LC_ALL=C HOME=/nonexistent PYTHONDONTWRITEBYTECODE=1 \
 /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 -S \
 <repo>/research/rapier-support-datum-runner-source-20261030/run_aggregate.py \
 --admitted-source-commit <verified-published-HEAD>
```

See the separately published `../rapier-support-datum-diagnostic-source-20261030/`
for unchanged selection/window/slope and all limitations. Source preparation and
stdlib validation are not execution of this native comparison.
