from pathlib import Path
import subprocess,os,json
H=Path(__file__).resolve().parent;P=H/'prefix'
env=os.environ.copy();env['LD_LIBRARY_PATH']=str(P/'usr/lib/x86_64-linux-gnu')
args=[str(P/'usr/bin/cmake'),'-S',str(H/'adapter'),'-B',str(H/'adapter-build'),'-DCMAKE_BUILD_TYPE=Release','-DRTABMap_DIR='+str(H/'build'),'-DCMAKE_PREFIX_PATH='+str(P/'usr')]
args += ['-DMPI_C_COMPILER_INCLUDE_DIRS='+str(P/'usr/lib/x86_64-linux-gnu/openmpi/include')+';'+str(P/'usr/lib/x86_64-linux-gnu/openmpi/include/openmpi'),'-DMPI_C_HEADER_DIR='+str(P/'usr/lib/x86_64-linux-gnu/openmpi/include'),'-DMPI_C_ADDITIONAL_INCLUDE_DIRS='+str(P/'usr/lib/x86_64-linux-gnu/openmpi/include/openmpi'),'-DMPI_C_LIB_NAMES=mpi','-DMPI_mpi_LIBRARY=/usr/lib/x86_64-linux-gnu/libmpi.so.40','-DMPI_C_COMPILER=/usr/bin/gcc']
(H/'ADAPTER_CONFIGURE_COMMAND.json').write_text(json.dumps(args,indent=2)+'\n')
r=subprocess.run(args,env=env,stdout=(H/'logs/adapter-configure.log').open('w'),stderr=subprocess.STDOUT,timeout=120);print(r.returncode);print((H/'logs/adapter-configure.log').read_text()[-3000:]);raise SystemExit(r.returncode)
