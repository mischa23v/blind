#!/usr/bin/env python3
"""Pure stdlib lossless serialization edge cases; no geometry/native imports."""
import pathlib,sys,unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from contact_codec import HEADER,canonical,decode_record,encode_record
class CodecTests(unittest.TestCase):
 def roundtrip(self,row):
  restored=decode_record(encode_record(row),HEADER);self.assertEqual(canonical(restored),canonical(row));self.assertEqual(restored,row)
 def test_absent_nested_and_empty(self):
  for r in [{},{'result':{}},{'sweep':None},{'result':None},{'result':{'extra':True}}]:self.roundtrip(r)
 def test_invalid_row(self):self.roundtrip({'status':'unavailable_native_height','queryExecuted':False,'contactIDs':None,'nativeHeightUnavailableReason':'clamped XZ','movementApplied':False,'physicalAuthority':False})
 def test_type_mismatches(self):
  for v in [False,0,0.0,None,'false',[],{}]:self.roundtrip({'movementApplied':v,'result':{'groundContactCount':v}})
 def test_unknown_and_reserved_keys(self):self.roundtrip({'schema':'custom','mask':17,'defaults':None,'remainingDictionary':{},'result':{'physicalAuthority':False,'unknown':'kept'},'contactIDs':[0,17,1234]})
 def test_exact_float_values(self):self.roundtrip({'a':[-0.0,1e-300,1.2345678901234567],'result':{'groundContactCount':0.0}})
 def test_default_mask_presence(self):
  packed=encode_record({'movementApplied':False});self.assertNotEqual(packed[0],0);self.assertEqual(packed[1],{});self.assertEqual(encode_record({}),[0,{}])
 def test_mutation_independence(self):
  r={'result':{'groundContactFaceIDsFirst16':[]}};p=encode_record(r);q=decode_record(p,HEADER);q['result']['groundContactFaceIDsFirst16'].append(1);self.assertEqual(r['result']['groundContactFaceIDsFirst16'],[])
 def test_bad_mask_and_overwrite_rejected(self):
  for p in [[True,{}],[-1,{}],[1<<30,{}],[1,{'movementApplied':True}], [1<<8,{}]]:
   with self.assertRaises(ValueError):decode_record(p,HEADER)
if __name__=='__main__':unittest.main()
