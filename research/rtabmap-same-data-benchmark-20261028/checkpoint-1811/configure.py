from pathlib import Path
import os,subprocess,json,re,hashlib
H=Path(__file__).resolve().parent;P=H/'prefix';S=H/'source/rtabmap-8cd2f81a735722402d1e220147c4e83a1a746eaf'
# Use exact existing system shared objects for unpacked development symlink targets.
links=[]
for pattern in ['libopencv*.so*','libboost*.so*','libvtk*.so*']:
 for sys in Path('/usr/lib/x86_64-linux-gnu').glob(pattern):
  target=P/'usr/lib/x86_64-linux-gnu'/sys.name
  if sys.is_file() and not target.exists() and not target.is_symlink():
   target.symlink_to(sys);links.append({'path':str(target),'systemTarget':str(sys.resolve()),'sha256':hashlib.sha256(sys.read_bytes()).hexdigest()})
for path in list((P/'usr/lib/x86_64-linux-gnu').glob('*')):
 if path.is_symlink() and not path.exists():
  target=path.parent/os.readlink(path);sys=Path('/usr/lib/x86_64-linux-gnu')/target.name
  if sys.is_file() and not target.exists() and not target.is_symlink():
   target.symlink_to(sys);links.append({'path':str(target),'systemTarget':str(sys.resolve()),'sha256':hashlib.sha256(sys.read_bytes()).hexdigest()})
(H/'SYSTEM_LIBRARY_LINKS.json').write_text(json.dumps(links,indent=2)+'\n')
env=os.environ.copy();env.update(LD_LIBRARY_PATH=str(P/'usr/lib/x86_64-linux-gnu'),CMAKE_PREFIX_PATH=str(P/'usr'),PKG_CONFIG_PATH=str(P/'usr/lib/x86_64-linux-gnu/pkgconfig'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1')
args=[str(P/'usr/bin/cmake'),'-S',str(S),'-B',str(H/'build'),'-DCMAKE_BUILD_TYPE=Release','-DCMAKE_INSTALL_PREFIX='+str(P/'usr'),'-DCMAKE_PREFIX_PATH='+str(P/'usr'),'-DBUILD_APP=OFF','-DBUILD_TOOLS=OFF','-DBUILD_EXAMPLES=OFF','-DBUILD_TESTING=OFF','-DBUILD_PERF_TESTS=OFF','-DBUILD_DOCUMENTATION=OFF','-DWITH_QT=OFF','-DWITH_OPENMP=OFF','-DPCL_OMP=OFF']
# Freeze all optional WITH_ flags OFF for geometry-only core, leave built-in TORO enabled.
text=(S/'CMakeLists.txt').read_text();opts=sorted(set(re.findall(r'(?i)option\(\s*(WITH_\w+)',text)))
args += ['-D'+x+'='+('ON'if x=='WITH_TORO'else'OFF') for x in opts if x not in ['WITH_QT','WITH_OPENMP']]
(H/'CONFIGURE_COMMAND.json').write_text(json.dumps({'argv':args,'envOverrides':{k:env[k]for k in ['LD_LIBRARY_PATH','CMAKE_PREFIX_PATH','PKG_CONFIG_PATH','OMP_NUM_THREADS','OPENBLAS_NUM_THREADS']}},indent=2)+'\n')
args += ['-DMPI_C_COMPILER_INCLUDE_DIRS='+str(P/'usr/lib/x86_64-linux-gnu/openmpi/include')+';'+str(P/'usr/lib/x86_64-linux-gnu/openmpi/include/openmpi'),'-DMPI_C_HEADER_DIR='+str(P/'usr/lib/x86_64-linux-gnu/openmpi/include'),'-DMPI_C_ADDITIONAL_INCLUDE_DIRS='+str(P/'usr/lib/x86_64-linux-gnu/openmpi/include/openmpi'),'-DMPI_C_LIB_NAMES=mpi','-DMPI_mpi_LIBRARY=/usr/lib/x86_64-linux-gnu/libmpi.so.40','-DMPI_C_COMPILER=/usr/bin/gcc']
p=subprocess.run(args,env=env,stdout=(H/'logs/configure.log').open('w'),stderr=subprocess.STDOUT,timeout=120)
print(p.returncode);print((H/'logs/configure.log').read_text()[-5000:])
