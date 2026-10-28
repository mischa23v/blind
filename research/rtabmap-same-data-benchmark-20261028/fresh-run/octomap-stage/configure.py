from pathlib import Path
import json,subprocess,os
S=Path(__file__).resolve().parent;H=S.parent;P=H/'prefix'
a=json.loads((H/'CONFIGURE_COMMAND.json').read_text())['argv'];a[a.index('-B')+1]=str(S/'build');a=[x.replace('-DWITH_OCTOMAP=OFF','-DWITH_OCTOMAP=ON')for x in a];a += [x for x in json.loads((H/'ADAPTER_CONFIGURE_COMMAND.json').read_text())if x.startswith('-DMPI_')]
env=os.environ.copy();env.update(LD_LIBRARY_PATH=str(P/'usr/lib/x86_64-linux-gnu')+':'+str(P/'usr/lib'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1')
(S/'CONFIGURE_COMMAND.json').write_text(json.dumps(a,indent=2)+'\n');r=subprocess.run(a,env=env,stdout=(S/'logs/configure.log').open('w'),stderr=subprocess.STDOUT,timeout=120);print(r.returncode);print((S/'logs/configure.log').read_text()[-1500:]);raise SystemExit(r.returncode)
