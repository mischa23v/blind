"""Codec/byte-contract tests, not detection, localization or navigation tests."""
from pathlib import Path
import copy,hashlib,json,unittest
from audit_decoded_fields import ExactDecoder,ROOT,validate_selection
from select_recorded_frames import safe_name

class DecoderContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.decoder=ExactDecoder();cls.metadata=json.loads((ROOT/'selected/metadata').read_text())
        cls.pixels=cls.metadata['dw']*cls.metadata['dh']
    def test_actual_depth_exact_recorded_hash(self):
        data=(ROOT/'selected/rgbd/0.depth').read_bytes();decoded=self.decoder.decode(data,self.pixels*4)
        original=(ROOT/'decoded/0.depth.f32le').read_bytes();self.assertEqual(decoded,original)
    def test_actual_confidence_exact_recorded_hash(self):
        data=(ROOT/'selected/rgbd/0.conf').read_bytes();decoded=self.decoder.decode(data,self.pixels)
        self.assertEqual(decoded,(ROOT/'decoded/0.confidence.u8').read_bytes());self.assertTrue(set(decoded)<=set(range(3)))
    def test_wrong_expected_length_is_rejected(self):
        data=(ROOT/'selected/rgbd/0.conf').read_bytes()
        for n in (self.pixels-1,self.pixels+1):
            with self.assertRaises(ValueError):self.decoder.decode(data,n)
    def test_truncated_and_invalid_stream_is_rejected(self):
        data=(ROOT/'selected/rgbd/0.depth').read_bytes()
        for bad in (data[:16],b'not a recorded stream',b'xxxx'+data[4:]):
            with self.assertRaises(ValueError):self.decoder.decode(bad,self.pixels*4)
    def test_input_output_allocation_bounds(self):
        for data,n in ((b'',1),(b'x',0),(b'x',True),(b'x',4*1024**2+1)):
            with self.assertRaises(ValueError):self.decoder.decode(data,n)
    def test_zip_path_guard(self):
        for bad in ('../x','/tmp/x','C:/x','a\\b','.','a/../../x'):
            with self.assertRaises(ValueError):safe_name(bad)
        self.assertEqual(safe_name('rgbd/0.conf'),'rgbd/0.conf')
    def test_no_tracking_or_mount_authority_is_manufactured(self):
        receipt=json.loads((ROOT/'FIELD_DECODE_AUDIT.json').read_text())
        self.assertFalse(receipt['nativeRecordedTransportUsed']);self.assertFalse(receipt['physicalNavigationAuthority'])
        self.assertFalse(receipt['originalTrackingStateAvailable']);self.assertFalse(receipt['bodyToPhoneExtrinsicsAvailable'])
        for row in receipt['frames']:
            self.assertEqual(row['trackingState'],'unknown');self.assertFalse(row['confidenceReplaced']);self.assertFalse(row['physicalNavigationAuthority'])
    def test_exact_selection_pin_ids_and_paths(self):
        good=json.loads((ROOT/'SELECTION_RECEIPT.json').read_text());validate_selection(good)
        for key,value in [('clipSHA256','other'),('frameIDs',[0]),('frameIDs',list(range(9)))]:
            bad=copy.deepcopy(good);bad[key]=value
            with self.assertRaises(ValueError):validate_selection(bad)
        bad=copy.deepcopy(good);bad['files'][0]['name']='../outside'
        with self.assertRaises(ValueError):validate_selection(bad)

if __name__=='__main__':unittest.main(verbosity=2)
