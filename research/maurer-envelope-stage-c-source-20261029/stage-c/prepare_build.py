#!/usr/bin/env python3
"""SOURCE PREPARATION ONLY. Writes scratch sources/command recipe, never executes it.

An independently reviewed, root-admitted Apple launch must enforce the frozen
envelope, resolve SDK/toolchain pins and verify all inputs again before/after.
"""
import argparse,difflib,hashlib,json,pathlib

HERE=pathlib.Path(__file__).resolve().parent
PACKET=HERE.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def blob(p):
    b=p.read_bytes();return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def replace_once(s,old,new):
    assert s.count(old)==1,old
    return s.replace(old,new,1)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository',type=pathlib.Path,required=True)
    parser.add_argument('--output',type=pathlib.Path,required=True)
    args=parser.parse_args();repo=args.repository.resolve(strict=True);out=args.output.resolve()
    assert not out.exists(),'Preserve earlier preparation; choose a fresh private output'
    assert PACKET in out.parents,'Scratch preparation must stay in this private packet'
    tree=json.loads((PACKET/'REMOTE_TREE.json').read_text())
    assert tree['sha']=='50ea33d6eb2cf37edcd4c1c7daa46f5c6fdd9dfa' and not tree['truncated']
    entries={x['path']:x for x in tree['tree'] if x['type']=='blob'}
    pins={}
    def pin_repo(path):
        p=repo/path;assert p.is_file() and blob(p)==entries[path]['sha'],path
        pins['@repository/'+path]={'bytes':p.stat().st_size,'sha256':sha(p),'gitBlob':entries[path]['sha']}
        return p
    def pin_packet(path):
        p=PACKET/path;assert p.is_file();pins['@packet/'+path]={'bytes':p.stat().st_size,'sha256':sha(p)};return p
    c='research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour'
    roots={'repository':'explicit exact checkout at launch','packet':'this frozen private packet',
           'build':'fresh isolated Apple output selected in admission','sdk':'validated installed macOS SDK selected in admission'}
    original_area=pin_repo(c+'/upstream/Recast/Source/RecastArea.cpp').read_text()
    observed_area=replace_once(original_area,'#include "Recast.h"',
        '#include "Recast.h"\nextern "C" void blind_seed_probe_stock(const rcCompactHeightfield&,const unsigned char*,int,int);')
    observed_area=replace_once(observed_area,
        '\tconst unsigned char minBoundaryDistance = (unsigned char)(erosionRadius * 2);',
        '\tblind_seed_probe_stock(compactHeightfield,distanceToBoundary,erosionRadius,0);\n'
        '\tconst unsigned char minBoundaryDistance = (unsigned char)(erosionRadius * 2);')
    observed_area=replace_once(observed_area,'\trcFree(distanceToBoundary);',
        '\tblind_seed_probe_stock(compactHeightfield,distanceToBoundary,erosionRadius,1);\n\trcFree(distanceToBoundary);')
    original_adapter=pin_packet('candidate/'+c+'/blind_detour_exclusion.cpp').read_text()
    observed_adapter=replace_once(original_adapter,'#include "exact_seed_radius_veto.h"',
        '#include "exact_seed_radius_veto.h"\nextern "C" void blind_seed_probe_after_veto(const rcCompactHeightfield&,const BNSeedRadiusVetoReceipt&);\nextern "C" void blind_seed_probe_after_envelope(const rcCompactHeightfield&,const BNSeedRadiusEnvelopeReceipt&);')
    observed_adapter=replace_once(observed_adapter,'    if (!rcBuildDistanceField(&context, *b.compact) ||',
        '    if (seedReceipt) blind_seed_probe_after_veto(*b.compact, *seedReceipt); // SCRATCH READ-ONLY OBSERVATION\n'
        '    if (envelopeReceipt) blind_seed_probe_after_envelope(*b.compact, *envelopeReceipt); // SCRATCH READ-ONLY OBSERVATION\n'
        '    if (!rcBuildDistanceField(&context, *b.compact) ||')
    appendix=pin_repo('research/native-floor-import-repair-20261028/strict-endpoint-probe/association_appendix.cpp')
    observed_adapter+='\n'+appendix.read_text()
    for p in ['main.swift','seed_probe.h','seed_observer.cpp','observer_tests.cpp','hook_test_digest.hpp','prepare_build.py']:
        pin_packet('stage-c/'+p)
    for p in ['include/blind_detour.h','exact_seed_radius_veto.h','exact_seed_radius_envelope.h','Envelope/candidate/seed_distance_maurer.h','Envelope/LICENSE','Envelope/NOTICE']:
        pin_packet('candidate/'+c+'/'+p)
    fixed={
      'research/native-floor-import-repair-20261028/strict-endpoint-probe/PACKED_ROUTING_GEOMETRY.json':'0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7',
      'research/native-floor-import-repair-20261028/strict-endpoint-probe/REQUESTS_49A.json':'e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51',
      'research/native-floor-import-repair-20261028/edt-navigation-probe/EDT_MASK_INPUTS.json':'13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a',
      'research/native-floor-import-repair-20261028/native-strict-result-40791907324/RESULT.json':'0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893'}
    for path,expected in fixed.items():assert sha(pin_repo(path))==expected
    oracle='ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift';pin_repo(oracle)
    pin_repo('research/room-mesh-package-75/BlindRoomMesh/Package.swift')
    pin_repo('research/room-mesh-package-75/BlindRoomMesh/LICENSE-Recast.txt')
    common=['xcrun','clang++','-std=c++14','-O1','-ffp-contract=off','-fno-rtti','-fno-exceptions',
      '-fPIC','-isysroot','@sdk','-target','arm64-apple-macosx14.0',
      '-I','@packet/candidate/'+c,'-I','@packet/candidate/'+c+'/include','-I','@packet/stage-c']
    for component in ['Recast','Detour','DetourCrowd']:
        common+=['-I','@repository/'+c+'/upstream/'+component+'/Include']
        for header in sorted((repo/c/'upstream'/component/'Include').glob('*.h')):pin_repo(str(header.relative_to(repo)))
    commands=[];objects=[]
    for component in ['Recast','Detour','DetourCrowd']:
        for source in sorted((repo/c/'upstream'/component/'Source').glob('*.cpp')):
            rel=str(source.relative_to(repo));pin_repo(rel)
            selected='@build/RecastArea-observed.cpp' if source.name=='RecastArea.cpp' else '@repository/'+rel
            obj='@build/'+component+'-'+source.stem+'.o'
            commands.append({'label':'compile-'+component+'-'+source.stem,'argv':common+['-c',selected,'-o',obj]});objects.append(obj)
    for source,label in [('@build/adapter-observed.cpp','adapter'),('@packet/stage-c/seed_observer.cpp','observer')]:
        obj='@build/'+label+'.o';commands.append({'label':'compile-'+label,'argv':common+['-c',source,'-o',obj]});objects.append(obj)
    library='@build/libseedprobe.a'
    commands.append({'label':'archive','argv':['xcrun','ar','rcs',library]+objects})
    commands.append({'label':'observer-tests-compile','argv':common+['@packet/stage-c/observer_tests.cpp',library,'-o','@build/observer-tests']})
    commands.append({'label':'observer-tests-run','argv':['@build/observer-tests'],'requireOrderedGroups':21})
    commands.append({'label':'swift-probe-compile','argv':['xcrun','swiftc','-j','1','-num-threads','1','-swift-version','5','-parse-as-library',
        '-sdk','@sdk','-target','arm64-apple-macosx14.0','-I','@build/include','@packet/stage-c/main.swift','@repository/'+oracle,library,'-lc++','-o','@build/seed-probe']})
    commands.append({'label':'probe-run','argv':['@build/seed-probe']+['@repository/'+x for x in fixed]+['@build/RESULT.private.json'],
        'requireAll50ControlsBefore25Candidate':True,'requireCandidateGoalsMet':True})
    out.mkdir(parents=True)
    (out/'RecastArea-observed.cpp').write_text(observed_area)
    (out/'adapter-observed.cpp').write_text(observed_adapter)
    inc=out/'include';inc.mkdir()
    (inc/'seed_probe.h').write_bytes((HERE/'seed_probe.h').read_bytes())
    (inc/'blind_detour.h').write_bytes((PACKET/'candidate'/c/'include/blind_detour.h').read_bytes())
    (inc/'module.modulemap').write_text('module SeedRadiusProbe { header "seed_probe.h" export * }\n')
    patch=''.join(difflib.unified_diff(original_area.splitlines(True),observed_area.splitlines(True),fromfile='production/RecastArea.cpp',tofile='scratch/RecastArea-observed.cpp'))
    patch+=''.join(difflib.unified_diff(original_adapter.splitlines(True),observed_adapter.splitlines(True),fromfile='candidate/blind_detour_exclusion.cpp',tofile='scratch/adapter-observed.cpp'))
    (out/'OBSERVATION_ONLY.patch').write_text(patch)
    generated={str(p.relative_to(out)):{'bytes':p.stat().st_size,'sha256':sha(p)} for p in out.rglob('*') if p.is_file()}
    recipe={'schema':1,'sourcePreparationOnly':True,'nativeExecuted':False,'executionAuthorized':False,
      'roots':roots,'requiredXcodeVersion':'Xcode 27.0','requiredCompileSerial':True,
      'SDKAndCompilerPins':'Must be frozen/resolved by independently reviewed Apple launch before compilation; not claimed known on Linux.',
      'sourcePins':pins,'generatedSources':generated,'commands':commands,
      'runtimeOutput':'Private. Publish only independently reviewed aggregates; no raw route/geometry arrays or binaries.',
      'activeAppOrViewerChanged':False,'physicalAuthority':False}
    (out/'BUILD_RECIPE.json').write_text(json.dumps(recipe,indent=2)+'\n')
    print(json.dumps({'sourcePreparationOnly':True,'pinnedInputs':len(pins),'generatedFiles':len(generated),
                      'commandsPreparedNotRun':len(commands),'nativeExecuted':False,'recipeSHA256':sha(out/'BUILD_RECIPE.json')}))

if __name__=='__main__':main()
