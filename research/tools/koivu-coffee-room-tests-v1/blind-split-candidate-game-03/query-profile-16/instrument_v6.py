"""Checked mechanical instrumentation; no optimization or algorithm rewrite."""
from pathlib import Path
import ast
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ORIGINAL = HERE.parent/'ground-obb-v6/oriented_ground_obb_container.py'
EXPECTED = '7005ab752d855edfdb1295b401ea8ad9d66516a5813f716f1a7818677bb1c222'

HELPERS = '''
    # Timing metadata is separate from every original collision result.
    def _profile_begin(self):
        self._profile_active={'index':len(self.profile_rows),'exceptionType':None,
            'phaseSeconds':{name:0. for name in PROFILE_PHASES},
            'ownerCheck':{'count':0,'seconds':0.,'byPhase':{}},
            'resultHelper':{'count':0,'seconds':0.,'byPhase':{}},
            'nestedTimesAreAdditiveToPhases':False,
            'ownerCheckIncludesInheritedOwnerChecks':True,
            'resultHelperIncludesItsOwnerCheck':True,
            'OBBFilterIncludesOwnerChecks':True,
            'exactLoopIncludesFirstHitResultHelper':True,
            'scope':'one contact_corners body; external swept_contacts checks excluded',
            'timingOverheadIncluded':True,'geometryOrPredicateChanged':False}
        self._profile_phase='validationTransformBoxSetup'
        self._profile_started=self._profile_cursor=_profile_time.perf_counter()

    def _profile_mark(self,phase):
        now=_profile_time.perf_counter()
        self._profile_active['phaseSeconds'][self._profile_phase]+=now-self._profile_cursor
        self._profile_phase=phase;self._profile_cursor=now

    def _profile_note_nested(self,kind,started):
        elapsed=_profile_time.perf_counter()-started
        if self._profile_active is not None:
            row=self._profile_active[kind];row['count']+=1;row['seconds']+=elapsed
            phase=row['byPhase'].setdefault(self._profile_phase,{'count':0,'seconds':0.})
            phase['count']+=1;phase['seconds']+=elapsed

    def _profile_finish(self):
        now=_profile_time.perf_counter();row=self._profile_active
        row['phaseSeconds'][self._profile_phase]+=now-self._profile_cursor
        row['contactTimedWallSeconds']=now-self._profile_started
        row['exclusivePhaseSumSeconds']=sum(row['phaseSeconds'].values())
        row['completed']=row['exceptionType'] is None
        self.profile_rows.append(row);self._profile_active=None

    def _oriented_result(self,*args,**kwargs):
        _profile_nested_started=_profile_time.perf_counter()
        try:
            return super()._oriented_result(*args,**kwargs)
        finally:
            self._profile_note_nested('resultHelper',_profile_nested_started)
'''

PHASES = ('validationTransformBoxSetup', 'nativeFindCellsWithinBounds',
          'getIdArrayExtraction', 'vectorizedGroundSplit', 'zeroCopyOBBFilter',
          'exactPredicateLoopAndSetup', 'resultAssemblyTail')


def replace_once(text, old, new):
    if text.count(old) != 1: raise ValueError('source anchor not unique: '+old[:70])
    return text.replace(old, new, 1)


def generate(original):
    text = replace_once(original, 'import sys\n', 'import sys\nimport time as _profile_time\nimport hashlib as _profile_hashlib\n')
    text = replace_once(text, 'class GroundOBBReferenceContainer(', 'class ProfiledGroundOBBReferenceContainer(')
    anchor = 'class ProfiledGroundOBBReferenceContainer('
    definitions = ("ORIGINAL_V6_SHA256='"+EXPECTED+"'\n"
        "_profile_original=ROOT/'ground-obb-v6/oriented_ground_obb_container.py'\n"
        "if _profile_hashlib.sha256(_profile_original.read_bytes()).hexdigest()!=ORIGINAL_V6_SHA256:\n"
        "    raise RuntimeError('frozen v6 instrumentation source changed')\n"
        'PROFILE_PHASES='+repr(PHASES)+'\n\n')
    text = replace_once(text, anchor, definitions+anchor)
    text = replace_once(text, '        super().__init__(*args,**kwargs)\n',
                        '        self.profile_rows=[];self._profile_active=None\n        super().__init__(*args,**kwargs)\n')
    begin = text.index('    def check(self):\n')
    end = text.index('    def _filter_box_bounds(', begin)
    body = text[begin+len('    def check(self):\n'):end].rstrip('\n')
    wrapped = ('    def check(self):\n        _profile_check_started=_profile_time.perf_counter()\n'
               '        try:\n'+''.join('    '+line+'\n' for line in body.splitlines())+
               '        finally:\n            self._profile_note_nested(\'ownerCheck\',_profile_check_started)\n\n')
    text = text[:begin]+wrapped+text[end:]
    text = replace_once(text, '        self.ids.Reset();self.surface.locator.FindCellsWithinBounds(bounds,self.ids)\n',
        "        self.ids.Reset()\n        self._profile_mark('nativeFindCellsWithinBounds')\n"
        '        self.surface.locator.FindCellsWithinBounds(bounds,self.ids)\n'
        "        self._profile_mark('validationTransformBoxSetup')\n")
    for anchor, phase in [
        ('        candidate_ids=np.fromiter(', 'getIdArrayExtraction'),
        ('        non_ground_ids,skipped_ids_array=self._split_candidate_ids(', 'vectorizedGroundSplit'),
        ('        exact_ids,bounds_receipt=self._filter_box_bounds(', 'zeroCopyOBBFilter'),
        ('        closest,pcoords,weights=[0.]*3,[0.]*3,[0.]*8\n', 'exactPredicateLoopAndSetup'),
        ("        result=first if first is not None else self._oriented_result(False,count,None,'noNonGroundReferenceSurfaceContact')\n", 'resultAssemblyTail')]:
        text = replace_once(text, anchor, "        self._profile_mark('"+phase+"')\n"+anchor)
    text = replace_once(text, '        exact_ids,bounds_receipt=self._filter_box_bounds(non_ground_ids,q)\n        self.check()\n',
        "        exact_ids,bounds_receipt=self._filter_box_bounds(non_ground_ids,q)\n        self._profile_mark('validationTransformBoxSetup')\n        self.check()\n")
    # Keep original docstring and wrap the complete contact body, retaining
    # every original statement/branch/return in the same relative order.
    node = next(n for n in ast.walk(ast.parse(text)) if isinstance(n, ast.FunctionDef) and n.name == 'contact_corners')
    lines = text.splitlines(keepends=True)
    first_body = node.body[1].lineno-1
    last_body = node.end_lineno
    body = ''.join(lines[first_body:last_body])
    wrapped = ('        self._profile_begin()\n        try:\n'+
               ''.join('    '+line if line.strip() else line for line in body.splitlines(keepends=True))+
               '        except BaseException as _profile_error:\n'
               "            self._profile_active['exceptionType']=type(_profile_error).__name__\n"
               '            raise\n        finally:\n            self._profile_finish()\n')
    text = ''.join(lines[:first_body])+wrapped+''.join(lines[last_body:])
    return text.rstrip()+'\n'+HELPERS


def original_method_nodes(text):
    cls = next(n for n in ast.parse(text).body if isinstance(n, ast.ClassDef))
    return {n.name:n for n in cls.body if isinstance(n, ast.FunctionDef)}


def verify_algorithm(original, generated):
    """Prove original method ASTs unchanged after deleting timing statements."""
    old = original_method_nodes(original); new = original_method_nodes(generated)
    new['__init__'].body = new['__init__'].body[2:]  # the two initialized profiling attributes
    new['check'].body = new['check'].body[1].body  # original body inside timing try/finally
    def is_mark(statement):
        return (isinstance(statement, ast.Expr) and isinstance(statement.value, ast.Call)
                and isinstance(statement.value.func, ast.Attribute)
                and statement.value.func.attr == '_profile_mark')
    contact = new['contact_corners']
    contact.body = [contact.body[0]]+[n for n in contact.body[2].body if not is_mark(n)]
    equal = {}
    for name in old:
        equal[name] = ast.dump(old[name], include_attributes=False) == ast.dump(new[name], include_attributes=False)
        if not equal[name]: raise ValueError('non-instrumentation AST change in '+name)
    return equal


def main():
    original = ORIGINAL.read_text()
    if hashlib.sha256(original.encode()).hexdigest() != EXPECTED: raise ValueError('original v6 source pin')
    generated = generate(original); equivalent = verify_algorithm(original, generated)
    target = HERE/'profiled_v6.py'
    if target.exists() and target.read_text() != generated: raise ValueError('refusing to overwrite a different profiled cut')
    target.write_text(generated)
    (HERE/'INSTRUMENTATION.diff').write_text(''.join(difflib.unified_diff(original.splitlines(keepends=True), generated.splitlines(keepends=True),fromfile='frozen-v6',tofile='profiled-v6')))
    receipt = {'originalSHA256':EXPECTED,'generatedSHA256':hashlib.sha256(generated.encode()).hexdigest(),
               'originalMethodASTsEqualAfterRemovingTimingOnly':equivalent,
               'phaseNames':list(PHASES),'optimizerAdded':False,'originalSourceChanged':False,
               'nestedDiagnosticsAdditiveToExclusivePhases':False,'physicalAuthority':False}
    (HERE/'GENERATION_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt))


if __name__ == '__main__': main()
