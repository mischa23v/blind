"""Report failures as failures. Never combine unknown stops with specific detections."""
import collections
import csv
import html
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1];out=root/'artifacts'/'stairs'
rows=json.loads((out/'replay-results.json').read_text())
room_path=root/'artifacts'/'real-scene'/'room-replay-results.json'
room=json.loads(room_path.read_text()) if room_path.exists() else []
dense_path=root/'artifacts'/'real-scene'/'room-dense-replay-results.json'
dense=json.loads(dense_path.read_text()) if dense_path.exists() else []
belt=list(csv.DictReader((out/'belt-elevation-score.csv').open()))
summary=[]
for direction,expected in [('Down','drop'),('Up','obstacle')]:
    cases=[r for r in rows if r['group']=='synthetic-step' and r['expected']==expected]
    summary.append(dict(test=f'Phone core: synthetic {direction.lower()} steps',cases=len(cases),
        specific=sum(r['specificMatch'] for r in cases),stop=sum(r['stopWarning'] for r in cases),
        unknown=sum(r['actual']=='uncertain' for r in cases)))
    cases=[r for r in belt if r['direction']==direction.lower()]
    found=sum(int(r['recognized']) for r in cases)
    summary.append(dict(test=f'Belt ground logic: ideal {direction.lower()} steps',cases=len(cases),specific=found,
        stop=found,unknown=0))
for group in ['synthetic-control','synthetic-unknown','synthetic-obstacle']:
    cases=[r for r in rows if r['group']==group]
    summary.append(dict(test=group,cases=len(cases),specific=sum(r['specificMatch'] for r in cases),
        stop=sum(r['stopWarning'] for r in cases),unknown=sum(r['actual']=='uncertain' for r in cases)))
if room:
    for expected in ['obstacle','observing']:
        cases=[r for r in room if r['expected']==expected]
        summary.append(dict(test=f'Real room mesh / virtual camera: expected {expected}',cases=len(cases),
            specific=sum(r['specificMatch'] for r in cases),stop=sum(r['stopWarning'] for r in cases),
            unknown=sum(r['actual']=='uncertain' for r in cases)))
report={'readiness':'Not ready for child walking trials','summary':summary,
    'limitations':['No physical belt/phone or child trial.',
       'Synthetic steps have ideal calibration and no sensor noise or sunlight model.',
       'Belt sweep isolates downward range logic with perfect constant mounting; other belt sensors are not simulated.',
       'Real stairs: fixed 12-frame subset, three assumed camera heights and unverified gravity convention. Outcomes are sensitivity diagnostics, not accuracy estimates.',
       'Real room: manually labelled expectations on reconstructed geometry, simulated first-hit camera rays; no live localization.',
       'Reported distance is a detector sample distance, not verified distance to the first stair edge.',
       'No valid physical latency, false-alarm-per-hour or child reaction-time score is available.'],
    'stairCases':rows,'roomCases':room,'beltCases':belt,'denseRoomFollowup':dense}
(out/'score.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
esc=html.escape
def table(items,fields):
    return '<table><thead><tr>'+''.join('<th>'+esc(f)+'</th>' for f in fields)+'</tr></thead><tbody>'+''.join(
        '<tr>'+''.join('<td>'+esc(str(item.get(f,'')))+'</td>' for f in fields)+'</tr>' for item in items)+'</tbody></table>'
text='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Elevation and room replay results</title><style>body{font:17px/1.55 system-ui;margin:2rem auto;max-width:1100px;padding:0 1rem;color:#172b38}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:8px;border:1px solid #bbc7cd;text-align:left}th{background:#edf2f4}img{width:100%;height:auto}details{margin:1.5rem 0;overflow:auto}summary{cursor:pointer;font-weight:bold}.status{border-left:5px solid #ac3939;padding:1rem;background:#fff0ed}code{overflow-wrap:anywhere}</style>
<h1>Elevation and room replay results</h1><p class="status"><strong>Not ready for child walking trials.</strong> The experiments found missed small steps in belt ground logic and limited specific classification in phone logic. A stop caused by uncertainty is reported separately from recognizing a hazard.</p>
<p>Real data, virtual sensor views and idealized geometry are explicitly separated below. No LLM participated.</p>
<h2>Scored test cases</h2>'''
text+=table(summary,['test','cases','specific','stop','unknown'])
text+='<p><b>specific</b>: exact requested category. <b>stop</b>: any danger/unavailable warning; not a successful classification. On level-floor controls, stopping is undesirable. Counts are descriptive, not a reliability percentage.</p>'
text+='<h2>Real staircase data inspected</h2><img src="rgb-contact-sheet.png" alt="Twelve recorded staircase RGB frames, including ascending, descending and dark scenes"><p>Wang et al., RGB-D stair dataset, DOI 10.17632/6kffmjt7g2.1, CC BY 4.0. Fixed indices: 0, 14, 28, 42, 56, 70, 84, 98, 112, 126, 140, 153. Frame 112 is an oblique landing and excluded from direction scoring.</p>'
text+='<p>The replay varies assumed camera height between 0.9, 1.2 and 1.5 m. Gravity-vector interpretation is unverified. These runs expose sensitivity to calibration; they are <b>not a legitimate real-data accuracy benchmark</b>. Do not present the stop count as successful stair recognition.</p>'
text+='<details><summary>All phone-core cases, including failures</summary>'+table(rows,['id','expected','actual','specificMatch','stopWarning','distance'])+'</details>'
text+='<details><summary>All belt ground range cases, including misses</summary>'+table(belt,['direction','step_cm','pitch_degrees','measured_mm','observed_flags','recognized'])+'</details>'
text+='<h2>Room with obstacles</h2><img src="../real-scene/scan-preview.png" alt="Real apartment reconstruction and observed-floor/obstacle/unknown inspection grid"><p>Huang, Dai, Guibas and Niessner, 3DLite initial apartment reconstruction, CC BY-NC-SA 4.0. Rays use this actual mesh, with synthetic camera poses. This is not a physical room trial.</p>'
text+=table(room,['id','expected','actual','specificMatch','stopWarning','distance']) if room else '<p>Room ray replay not completed; no room score claimed.</p>'
if room:
    text+='<img src="../real-scene/room-replay-preview.png" alt="Six actual virtual ray returns, colored by height, with original expected labels and observed detector results">'
if dense:
    text+='<h2>Follow-up: denser virtual camera sampling</h2><p>Same poses, labels and detector; 128x96 rays instead of 64x48. This follow-up was chosen after seeing the baseline failures, so it is not an independent validation set. The original scores above remain unchanged. The live sampler was subsequently made denser; actual iPhone performance and effectiveness remain untested.</p>'
    text+=table(dense,['id','expected','actual','specificMatch','stopWarning','sampleCount'])
text+='<h2>Limits</h2><ul>'+''.join('<li>'+esc(s)+'</li>' for s in report['limitations'])+'</ul>'
text+='<p>Reproduce using tools/download-stairs.py, tools/make-sensor-replay.py, tools/make-room-replay.py, the SensorReplay Swift executable, firmware/test/elevation_score.cpp and tools/score-sensor-replay.py.</p></html>'
(out/'score.html').write_text(text,encoding='utf-8')
print(json.dumps(summary,indent=2))
