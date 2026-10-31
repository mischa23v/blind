"""Render frozen primary and secondary JSON; no geometry query or score tuning."""
from pathlib import Path
import json,hashlib
H=Path(__file__).resolve().parent;W=H.parent.parent;D=H/'C1_N3';OLD=W/'coordination/voxfield-recovered-full265-same-protocol-score'
paths={'Supplied-pose Open3D':W/'research/open3d-same-data-benchmark-20261028/fresh-run/COMMON_GEOMETRY_RESULTS.json','B':OLD/'B/COMMON_GEOMETRY_RESULTS.json','C0':OLD/'C0/COMMON_GEOMETRY_RESULTS.json','C1_N2':OLD/'C1/COMMON_GEOMETRY_RESULTS.json','C1_N3':D/'COMMON_GEOMETRY_RESULTS.json'}
results={name:json.loads(path.read_text())for name,path in paths.items()};secondary=json.loads((D/'SECONDARY_COMMON_PAIRS.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def n(v):return f'{v:,}'
def cm(v):return '—' if v is None else f'{v*100:.3f}'
def pct(a,b):return '—' if not b else f'{100*a/b:.3f}%'
names=list(results);keys=[('all','All reference ranges'),('referenceBelow4m','Reference below 4 m'),('referenceAtLeast4m','Reference at least 4 m')]
for j in results.values():
 assert j['status']=='completed' and j['views']==29 and j['scheduledRays']==1335885 and j['pixelOffset']==0 and j['sampleStride']==4
 for q in [j['pooled']]+j['frames']:
  a=q['availability'];assert sum(a[k]for k in ['paired','referenceOnly','TSDFOnly','neither'])==a['scheduled']
  for s in [q[k]for k,_ in keys]+q['byReferenceDepth']:
   assert all(sum(b.values())==s['statistics']['count']for b in s['earlyWithinLate'].values())
lines=['# N3 normal-provider comparison: unchanged real-data geometry score','',
 '**Measured outcome: mixed, not an across-the-board improvement.** N3 gains some reference-paired coverage and slightly improves median/±5 cm agreement versus C1_N2, but pooled p95/p99/mean and longer-reference-range tails worsen. Exact-common-paired analysis confirms that the pooled/far-tail regression is not merely a change of hit subset. Do not claim an overall winner or promote a synthetic normal improvement into a navigation claim.','',
 '## Experiment, preserved failures, and validation','',
 '- Same original 265 training frames / 164,771,607 admitted points; same D1 core, original pixel inputs/order/K/poses/colors, TSDF/NP/mesh parameters. C1_N3 changes only the tested numerical-normal provider: four-export-pixel support plus intermediate-validity policy, rather than N2 one-pixel support, for this upsampled Koivu export. This is not a universal native-phone stencil or pure angle-only ablation.','- First N3 full attempt remains ENVIRONMENT_INTERRUPTED at 159 completed / 160 attempted frames, no final mesh/resource receipt, cap compliance unknown. The separately admitted retry starts from an empty map; no TSDF resume. The earlier N2 three-arm 300-CPU-second failure and its separate B/C0/C1 recovery are also preserved.','- Same 29 heldout views, original poses/K, 1,335,885 integer-pixel stride-four rays, immutable FARO cache, original 2/5/10 cm bands and depth strata. No GT mapping input, fit, scale adjustment, excluded ray, classifier or mesh repair. Primary evaluator/summary differ only by paths and the existing tsdf-only guard.','- Primary score and pre-frozen secondary comparisons completed once inside the same 60 CPU / 90 wall-second / 1 CPU / 1 GiB RSS / 1 GiB output guard. Prior N2 118-pin output freeze and original source/input/cache pins verified unchanged before and after.','',
 '## Primary coverage: all scheduled rays','', '| Metric | '+' | '.join(names)+' |','|---|'+'---:|'*len(names)]
for k,label in [('scheduled','Scheduled'),('paired','Paired positive hits'),('referenceOnly','Reference-only / mapper miss'),('TSDFOnly','Mapper-only / reference miss'),('neither','Neither')]:lines.append('| '+label+' | '+' | '.join(n(results[name]['pooled']['availability'][k])for name in names)+' |')
stats=[('count','Paired denominator',n),('absoluteP50','Median absolute cm',cm),('MAE','Mean absolute cm',cm),('absoluteP90','p90 absolute cm',cm),('absoluteP95','p95 absolute cm',cm),('absoluteP99','p99 absolute cm',cm),('maximumAbsolute','Maximum absolute cm',cm),('meanSigned','Mean signed cm',cm),('signedP05','Signed p05 cm',cm),('signedP50','Signed median cm',cm),('signedP95','Signed p95 cm',cm)]
for key,title in keys:
 lines+=['',f'## Primary: {title}','', '| Metric | '+' | '.join(names)+' |','|---|'+'---:|'*len(names)]
 lines.append('| Scheduled stratum denominator | '+' | '.join(n(results[name]['pooled'][key]['scheduled'])for name in names)+' |')
 for field,label,fn in stats:lines.append('| '+label+' | '+' | '.join(fn(results[name]['pooled'][key]['statistics'][field])for name in names)+' |')
 lines+=['','| Band | Mapper | Earlier | Within | Later | Within / paired |','|---|---|---:|---:|---:|---:|']
 for t in ['0.02','0.05','0.1']:
  for name in names:
   s=results[name]['pooled'][key];b=s['earlyWithinLate'][t];lines.append(f'| ±{float(t)*100:g} cm | {name} | '+' | '.join(n(b[k])for k in ['earlier','within','later'])+' | '+pct(b['within'],s['statistics']['count'])+' |')
lines+=['','## Primary original seven reference-depth bins','', '| Bin | Mapper | Scheduled reference hits | Paired | Ref-only | Median cm | p95 cm | p99 cm | ±5 cm count / paired |','|---|---|---:|---:|---:|---:|---:|---:|---|']
for i in range(7):
 for name in names:
  g=results[name]['pooled']['byReferenceDepth'][i];s=g['statistics'];within=g['earlyWithinLate']['0.05']['within']
  lines.append(f"| {g['label']} | {name} | {n(g['scheduled'])} | {n(s['count'])} | {n(g['scheduled']-s['count'])} | {cm(s['absoluteP50'])} | {cm(s['absoluteP95'])} | {cm(s['absoluteP99'])} | {n(within)} / {n(s['count'])} ({pct(within,s['count'])}) |")
lines+=['','## Secondary: exact common rays and coverage transitions','',
 'Frozen before candidate scoring, saved arrays only. For every reference-positive ray: common paired, gained paired, lost paired, or neither paired. Common errors compare both methods on exactly the same rays. Gained/lost rows show only the available mapper error; no missing error is imputed. These are numerical hit categories, not hazard labels or route-success counts.','']
secondary_group_count=0
for baseline,comp in secondary['comparisons'].items():
 for node in [comp['pooled']]+comp['frames']:
  for group in [node[k]for k,_ in keys]+node['byReferenceDepth']:
   c=group['coverage'];assert sum(c[k]for k in ['commonPaired','gainedPaired','lostPaired','neitherPaired'])==c['referencePositive']
   for side,key in [('commonBefore','commonPaired'),('commonAfter','commonPaired'),('gainedAfterOnly','gainedPaired'),('lostBeforeOnly','lostPaired')]:
    e=group[side];assert e['statistics']['count']==c[key] and all(sum(b.values())==c[key]for b in e['earlyWithinLate'].values())
   secondary_group_count+=1
 lines += [f'### C1_N3 versus {baseline}','', '| Reference range | Reference-positive | Old paired | New paired | Common | Gained | Lost | Neither paired |','|---|---:|---:|---:|---:|---:|---:|---:|']
 for key,title in keys:
  c=comp['pooled'][key]['coverage'];lines.append('| '+title+' | '+' | '.join(n(c[k])for k in ['referencePositive','beforePaired','afterPaired','commonPaired','gainedPaired','lostPaired','neitherPaired'])+' |')
 lines+=['','| Range | Subset / mapper | Count | Median cm | MAE cm | p90 cm | p95 cm | p99 cm | Maximum cm | Mean signed cm | ±2 cm / count | ±5 cm / count | ±10 cm / count |','|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
 for key,title in keys:
  for side,label in [('commonBefore','Common / '+baseline),('commonAfter','Common / C1_N3'),('gainedAfterOnly','Gained / C1_N3 only'),('lostBeforeOnly','Lost / '+baseline+' only')]:
   e=comp['pooled'][key][side];s=e['statistics'];count=s['count']
   lines.append('| '+title+' | '+label+' | '+n(count)+' | '+' | '.join(cm(s[k])for k in ['absoluteP50','MAE','absoluteP90','absoluteP95','absoluteP99','maximumAbsolute','meanSigned'])+' | '+' | '.join(f"{n(e['earlyWithinLate'][t]['within'])}/{n(count)} ({pct(e['earlyWithinLate'][t]['within'],count)})"for t in ['0.02','0.05','0.1'])+' |')
 m=comp['pooled']['referenceMissingCoverage'];lines+=['', 'Reference-missing rays, kept outside error/depth strata: '+', '.join(f'{k}={n(v)}'for k,v in m.items())+'.','', '| Reference-depth bin | Common | Gained | Lost | Old common p95 cm | N3 common p95 cm | Old common p99 cm | N3 common p99 cm |','|---|---:|---:|---:|---:|---:|---:|---:|']
 for g in comp['pooled']['byReferenceDepth']:
  c=g['coverage'];b=g['commonBefore']['statistics'];a=g['commonAfter']['statistics'];lines.append('| '+g['label']+' | '+' | '.join(n(c[k])for k in ['commonPaired','gainedPaired','lostPaired'])+' | '+' | '.join(cm(s[k])for s,k in [(b,'absoluteP95'),(a,'absoluteP95'),(b,'absoluteP99'),(a,'absoluteP99')])+' |')
 lines+=['','| View | Common | Gained | Lost | Old common median cm | N3 common median cm | Old common p95 cm | N3 common p95 cm |','|---|---:|---:|---:|---:|---:|---:|---:|']
 for frame in comp['frames']:
  g=frame['all'];c=g['coverage'];b=g['commonBefore']['statistics'];a=g['commonAfter']['statistics'];lines.append('| '+frame['frameID']+' | '+' | '.join(n(c[k])for k in ['commonPaired','gainedPaired','lostPaired'])+' | '+' | '.join(cm(s[k])for s,k in [(b,'absoluteP50'),(a,'absoluteP50'),(b,'absoluteP95'),(a,'absoluteP95')])+' |')
 lines+=['']
assert secondary_group_count==600
lines+=['## Primary per-view coverage and tails','', 'Every row retains 46,065 scheduled rays. Full per-view signed quantiles, all bands and depth strata remain in each unchanged JSON summary.','', '| View | Mapper | Paired | Ref-only | Map-only | Neither | Median cm | p95 cm | p99 cm | ±5 cm / paired |','|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
for i in range(29):
 for name in names:
  f=results[name]['frames'][i];a=f['availability'];s=f['all']['statistics'];within=f['all']['earlyWithinLate']['0.05']['within'];assert a['scheduled']==46065
  lines.append('| '+f['frameID']+' | '+name+' | '+' | '.join(n(a[k])for k in ['paired','referenceOnly','TSDFOnly','neither'])+' | '+' | '.join(cm(s[k])for k in ['absoluteP50','absoluteP95','absoluteP99'])+f" | {n(within)}/{n(s['count'])} ({pct(within,s['count'])}) |")
r=json.loads((D/'RESOURCE.json').read_text());assert r['exitCode']==0 and r['stopReason']is None
lines+=['','## Interpretation','',
 'Versus C1_N2, N3 has 879 gained pairs and 395 lost pairs (net +484), plus 414 more mapper-only hits. Newly paired rays are not automatically accurate: their available-side median error is 23.980 cm and p95 is 322.235 cm. Lost pairs had old-mapper median 18.063 cm and p95 205.898 cm. Neither side is imputed as correct or clear.','',
 'On the identical 1,190,087 common rays, N3 median improves slightly (3.307→3.289 cm), while p95 worsens (101.222→101.621 cm) and p99 worsens (279.234→280.006 cm). Within reference <4 m, common p95 changes only 99.660→99.601 cm; at ≥4 m it worsens 120.439→123.452 cm. The primary all-paired ≥4 m p95 worsens 120.483→124.181 cm. This does not justify an overall upgrade.','',
 'Against B, common pooled p95 improves but common median and far-reference tails worsen. Against original supplied-pose Open3D, primary N3 near-reference p95 remains worse (99.887 versus 90.941 cm). These metric trade-offs are preserved, not combined into a weighted winner.','',
 'FARO is author-registered and edited/completed; registration/completion uncertainty is unbounded. Missing hits never establish free space. Signed errors and one-sided hits are not obstacle labels. This capture does not demonstrate live localization, route success, hazard accuracy, object handling, full-body clearance, device performance or safe guidance.','',
 '## Resources and exact outputs','',f"Fresh primary + secondary: {r['wallSeconds']:.3f} wall seconds, {r['finalActualChildPlusGuardCPUSeconds']:.3f} guard+child CPU seconds, {r['peakSummedRSSBytes']/1024**2:.3f} MiB peak summed RSS. Exit 0 / no stop reason. All before/after source/input/reference-cache/prior-N2 pins unchanged.",'']
for name,path in paths.items():lines.append(f'- {name}: `{path.relative_to(W)}`, SHA256 `{sha(path)}`.')
lines.append(f"- Frozen secondary: `{(D/'SECONDARY_COMMON_PAIRS.json').relative_to(W)}`, SHA256 `{sha(D/'SECONDARY_COMMON_PAIRS.json')}`.")
lines+=['','Independent saved-array recount passed: 300 primary groups, 600 secondary coverage groups and 2,400 secondary error subsets; all per-view/pooled/depth-bin statistics, bands and transition denominators matched. See INDEPENDENT_ARRAY_RECOUNT.json. No mesh/reference requery was performed by the reviewer.']
(H/'COMPARISON.md').write_text('\n'.join(lines)+'\n');print('Rendered',len(lines),'lines; all primary/secondary group count invariants checked.')
