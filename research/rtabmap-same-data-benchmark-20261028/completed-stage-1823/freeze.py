from pathlib import Path
import json,hashlib,datetime
H=Path(__file__).resolve().parent
paths=['PROTOCOL.md','adapter/main.cpp','adapter/mapper.cpp','adapter/CMakeLists.txt','adapter/INPUTS.tsv','prepare_inputs.py','guard.py','CONFIGURE_COMMAND.json','ADAPTER_CONFIGURE_COMMAND.json','INPUT_RECEIPT.json','DOWNLOAD_LEDGER.json','PCL_CONFIG_RELOCATION.json','SYSTEM_LIBRARY_LINKS.json','adapter-build/koivu_rtab_component','adapter-build/koivu_rtab_mapper']
files=[]
for rel in paths:
 p=H/rel;assert p.is_file(),rel;files.append({'path':rel,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
for p in (H/'build/bin').glob('*.so*'):
 if p.is_file() and not p.is_symlink():files.append({'path':str(p.relative_to(H)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
f=H/'PRE_RUN_FREEZE.json';assert not f.exists(),'do not overwrite a frozen pre-run record';f.write_text(json.dumps({'timestampUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':files},indent=2)+'\n');print(f)
