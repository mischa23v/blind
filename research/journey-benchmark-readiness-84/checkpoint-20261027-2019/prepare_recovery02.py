"""Isolate a frozen continuation only after two inaccessible producers stay unchanged."""
from pathlib import Path
import datetime,hashlib,json,shutil
BASE=Path(__file__).resolve().parents[1]
OLD=BASE/'evaluator-forward-recovery-01'; NEW=BASE/'evaluator-forward-recovery-02'
EXPECTED='3d17b1b816abd553fde50ea9702e35b4bcd380d10b18375f5535be2a5101b525'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def size(p):return sum(f.stat().st_size for f in p.rglob('*') if f.is_file())
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def main():
 initial=json.loads((OLD/'reviews/EPISODE15_LIVENESS_INITIAL.json').read_text())
 assert datetime.datetime.now(datetime.timezone.utc)>=datetime.datetime.fromisoformat(initial['deadlinePlusGraceUTC'])
 first=json.loads((OLD/'RECOVERY_PREFLIGHT.json').read_text()); watches={str(BASE/'evaluator-forward'):{k:{'bytes':v[0],'mtimeNs':v[1],'sha256':v[2]} for k,v in first['originalWatch'].items()},str(OLD):initial['watch']}
 def check():
  for root,entries in watches.items():
   for n,x in entries.items():
    f=Path(root)/n; assert f.stat().st_size==x['bytes'] and f.stat().st_mtime_ns==x['mtimeNs'] and sha(f)==x['sha256'],(root,n,'producer evidence changed')
 check(); matrix=json.loads((OLD/'MATRIX.json').read_text()); required=size(BASE)+size(OLD)+matrix['episodeLimits']['outputBytes']; assert required<matrix['stageDiskCapBytes']; assert shutil.disk_usage(BASE).free>size(OLD)+768*1024**2
 available=int(next(x.split()[1] for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:')))*1024; assert available>=matrix['minimumAvailableRAMBytes']
 assert not NEW.exists();shutil.copytree(OLD,NEW,ignore=shutil.ignore_patterns('ACTIVE_RUN.lock','__pycache__'))
 check(); assert sha(NEW/'FROZEN.json')==EXPECTED
 for manifest in ['FROZEN.json','CACHE_MANIFEST.json']:
  assert sha(NEW/manifest)==sha(OLD/manifest)
  for n,digest in json.loads((NEW/manifest).read_text())['files'].items():assert sha(NEW/n)==digest,(manifest,n)
 ledger=json.loads((NEW/'EPISODE_LEDGER.json').read_text()); assert ledger[15]['status']=='running'; assert all(x['status']=='notRun' for x in ledger[16:]); partial=json.loads((NEW/'episodes/episode-015/result/LIVE_PROGRESS.json').read_text()); assert not (NEW/'episodes/episode-015/result/RESULT.json').exists()
 ledger[15].update(status='interruptedUnknown',movementExecuted=None,actualDistanceMetres=None,processCompleted=False,arrival=False,partialProgress=partial,partialProgressNotTerminal=True,partialTracePath='episodes/episode-015/result/ACTUAL_TRACE_PARTIAL.csv',failure='producer/session inaccessible; no terminal receipt; unchanged through deadline plus60s; not rerun',recoveryRecord='RECOVERY02_PREFLIGHT.json');save(NEW/'EPISODE_LEDGER.json',ledger)
 receipt={'createdUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'primaryForPendingEpisodeIndices':list(range(16,100)),'episode15Rerun':False,'episode15TerminalOutcome':'unknown','episode15KnownPartialMovement':partial,'previousRootsUntouched':True,'previousProducersAuthoritativelyTerminated':False,'briefOverlapRiskAcknowledged':True,'previousEvidenceUnchangedThroughDeadlinePlus60Seconds':True,'watches':watches,'frozenManifestSHA256':EXPECTED,'cacheManifestSHA256':sha(NEW/'CACHE_MANIFEST.json'),'combinedStageBytes':size(BASE),'stageCapBytes':matrix['stageDiskCapBytes'],'minimumAvailableRAMBytes':matrix['minimumAvailableRAMBytes'],'physicalAuthority':False,'execution':'one bounded episode per live exec session; no daemon or detach; previous-root watches every1s; original frozen code unchanged'}
 assert receipt['combinedStageBytes']<receipt['stageCapBytes'];save(NEW/'RECOVERY02_PREFLIGHT.json',receipt);print(json.dumps(receipt,indent=2))
if __name__=='__main__':main()
