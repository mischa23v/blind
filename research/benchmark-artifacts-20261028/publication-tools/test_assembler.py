import copy, hashlib, json, pathlib, tempfile, unittest
import assemble_binary_publication as a
import restore_benchmarks as r

class AssemblyTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=pathlib.Path(self.tmp.name)
        self.path=a.PREFIX+'archives/example.tar.gz';self.body=b'bounded synthetic archive bytes\x00\xff'*9
        self.original=self.write_binary('original',self.path,self.body)
        index={'scope':'synthetic only','archives':[{'repoPath':self.path,'bytes':len(self.body),'sha256':self.original['sha256'],'members':[{'path':'fixture','bytes':1,'sha256':'0'*64}]}]}
        self.index=self.root/'index.json';self.index.write_text(json.dumps(index));ir=self.write_binary('indexcopy',a.PREFIX+'ARCHIVE_RESTORE_INDEX.json',self.index.read_bytes());ir['localPath']=str(self.index);ir['encoding']='utf-8'
        self.manifest=self.root/'manifest.json';self.manifest.write_text(json.dumps({'files':[self.original,ir],'errors':[]}))
        self.receipt=self.root/'receipts.json';self.rootreceipt=self.root/'root.json';self.rootreceipt.write_text(json.dumps({'repo':a.REPOSITORY,'receipts':[]}));self.parts=self.root/'parts.json';self.parts_paths=[]
        self.set_receipts([self.confirm(self.original)])
    def write_binary(self,name,repo,data):
        p=self.root/name;p.write_bytes(data)
        return {'localPath':str(p),'repoPath':repo,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'gitBlobSha':hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest(),'mode':'100644','encoding':'base64'}
    def confirm(self,row):return dict(row,returnedGitblobSHA=row['gitBlobSha'],status='verified_uploaded')
    def set_receipts(self,rows):self.receipt.write_text(json.dumps(rows))
    def run_assembly(self):return a.assemble(self.manifest,[self.receipt],self.parts_paths,self.rootreceipt,self.root/'output')
    def set_parts(self):
        self.part_rows=[self.write_binary('part1',self.path+'.part001',self.body[:50]),self.write_binary('part2',self.path+'.part002',self.body[50:])]
        self.parts.write_text(json.dumps({'repo':a.REPOSITORY,'originals':[dict(self.original,parts=self.part_rows)]}));self.parts_paths=[self.parts];self.set_receipts([self.confirm(x) for x in self.part_rows])
    def test_confirmed_single(self):
        result=self.run_assembly();self.assertTrue(result['allBinaryUploadsConfirmed']);self.assertEqual(result['confirmedTreeEntries'],1)
    def test_confirmed_ordered_parts_and_original_hashes_preserved(self):
        self.set_parts();result=self.run_assembly();self.assertTrue(result['allBinaryUploadsConfirmed']);self.assertEqual(result['confirmedTreeEntries'],2);self.assertTrue(result['splitReconstructionChecks'][0]['passed'])
        index=json.loads((self.root/'output/ARCHIVE_RESTORE_INDEX.json').read_text());self.assertEqual(index['archives'][0]['sha256'],self.original['sha256']);self.assertEqual(index['archives'][0]['members'][0]['path'],'fixture')
    def test_verified_local_hash_is_not_upload_confirmation(self):
        self.set_receipts([dict(self.original,verified=True,status='pending')]);result=self.run_assembly();self.assertEqual(result['confirmedTreeEntries'],0);self.assertFalse(result['allBinaryUploadsConfirmed'])
    def test_uncertain_returned_sha_rejected(self):
        self.set_receipts([dict(self.confirm(self.original),status='uncertain')])
        with self.assertRaisesRegex(a.Invalid,'unconfirmed status'):self.run_assembly()
    def test_wrong_returned_sha_rejected(self):
        self.set_receipts([dict(self.confirm(self.original),returnedGitblobSHA='0'*40)])
        with self.assertRaisesRegex(a.Invalid,'differs from pinned'):self.run_assembly()
    def test_original_tampering_rejected(self):
        pathlib.Path(self.original['localPath']).write_bytes(b'changed')
        with self.assertRaisesRegex(a.Invalid,'mismatch'):self.run_assembly()
    def test_part_tampering_rejected(self):
        self.set_parts();pathlib.Path(self.part_rows[0]['localPath']).write_bytes(b'x'*50)
        with self.assertRaisesRegex(a.Invalid,'mismatch'):self.run_assembly()
    def test_reordered_parts_rejected(self):
        self.set_parts();d=json.loads(self.parts.read_text());d['originals'][0]['parts'].reverse();self.parts.write_text(json.dumps(d))
        with self.assertRaisesRegex(a.Invalid,'contiguous ordered'):self.run_assembly()
    def test_valid_part_hashes_wrong_reconstruction_rejected(self):
        self.set_parts();bad=self.write_binary('part1',self.path+'.part001',b'x'*50);self.part_rows[0]=bad;self.parts.write_text(json.dumps({'originals':[dict(self.original,parts=self.part_rows)]}));self.set_receipts([self.confirm(x) for x in self.part_rows])
        with self.assertRaisesRegex(a.Invalid,'concatenation.*mismatch'):self.run_assembly()
    def test_only_confirmed_part_enters_tree(self):
        self.set_parts();self.set_receipts([self.confirm(self.part_rows[0]),dict(self.part_rows[1],status='pending')]);result=self.run_assembly();self.assertEqual(result['confirmedTreeEntries'],1);self.assertFalse(result['allBinaryUploadsConfirmed'])
    def test_unknown_receipt_path_rejected(self):
        self.set_receipts([dict(self.confirm(self.original),repoPath='unknown')])
        with self.assertRaisesRegex(a.Invalid,'absent from allowlist'):self.run_assembly()
    def test_receipt_metadata_mismatch_rejected(self):
        self.set_receipts([dict(self.confirm(self.original),sha256='0'*64)])
        with self.assertRaisesRegex(a.Invalid,'receipt.*mismatch'):self.run_assembly()
    def test_conflicting_returned_fields_rejected(self):
        self.set_receipts([dict(self.confirm(self.original),GitHubSHA='0'*40)])
        with self.assertRaisesRegex(a.Invalid,'conflicting explicit'):self.run_assembly()
    def test_batch_two_returned_github_alias_alone_accepted(self):
        row=dict(self.original,returnedGitHubSHA=self.original['gitBlobSha'],status='verified_uploaded');self.set_receipts([row]);self.assertTrue(self.run_assembly()['allBinaryUploadsConfirmed'])
    def test_batch_two_inconsistent_duplicate_sha_rejected(self):
        self.set_receipts([dict(self.confirm(self.original),returnedGitHubSHA='0'*40)])
        with self.assertRaisesRegex(a.Invalid,'conflicting explicit'):self.run_assembly()
    def test_root_expected_sha_alias_accepted(self):
        row=self.confirm(self.original);row['expectedGitblobSHA']=row.pop('gitBlobSha');self.set_receipts([row]);self.assertTrue(self.run_assembly()['allBinaryUploadsConfirmed'])
    def test_conflicting_expected_sha_alias_rejected(self):
        self.set_receipts([dict(self.confirm(self.original),expectedGitblobSHA='0'*40)])
        with self.assertRaisesRegex(a.Invalid,'conflicting expected'):self.run_assembly()
    def test_pending_original_then_root_confirmation(self):
        self.set_receipts([dict(self.original,verified=True,status='pending')]);self.rootreceipt.write_text(json.dumps({'receipts':[self.confirm(self.original)]}));result=self.run_assembly();self.assertTrue(result['allBinaryUploadsConfirmed']);self.assertEqual(result['confirmedTreeEntries'],1)
    def test_missing_receipt_reported_not_invented(self):
        self.receipt.unlink();result=self.run_assembly();self.assertFalse(result['allBinaryUploadsConfirmed']);self.assertEqual(result['confirmedTreeEntries'],0);self.assertIn(str(self.receipt),result['missingInputs'])
    def test_index_tampering_rejected(self):
        self.index.write_text('{}')
        with self.assertRaisesRegex(a.Invalid,'source restore index'):self.run_assembly()
    def test_duplicate_manifest_path_rejected(self):
        m=json.loads(self.manifest.read_text());m['files'].append(self.original);self.manifest.write_text(json.dumps(m))
        with self.assertRaisesRegex(a.Invalid,'duplicate publication'):self.run_assembly()
    def restore_setup(self):
        self.set_parts();self.run_assembly();checkout=self.root/'checkout';out=self.root/'restored';out.mkdir()
        for p in self.part_rows:
            target=checkout/p['repoPath'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pathlib.Path(p['localPath']).read_bytes())
        row=json.loads((self.root/'output/ARCHIVE_RESTORE_INDEX.json').read_text())['archives'][0]
        return checkout,out,row
    def test_restore_exact_reconstruction(self):
        checkout,out,row=self.restore_setup();result=r.reconstruct(checkout,out,row);self.assertTrue(result['verified']);self.assertEqual((out/'example.tar.gz').read_bytes(),self.body)
    def test_restore_corruption_leaves_no_archive_or_temp(self):
        checkout,out,row=self.restore_setup();(checkout/self.part_rows[0]['repoPath']).write_bytes(b'bad')
        with self.assertRaises(r.Invalid):r.reconstruct(checkout,out,row)
        self.assertEqual(list(out.iterdir()),[])
    def test_restore_never_overwrites(self):
        checkout,out,row=self.restore_setup();(out/'example.tar.gz').write_bytes(b'keep')
        with self.assertRaisesRegex(r.Invalid,'refusing existing'):r.reconstruct(checkout,out,row)
        self.assertEqual((out/'example.tar.gz').read_bytes(),b'keep')
    def test_restore_rejects_traversal(self):
        with self.assertRaisesRegex(r.Invalid,'unsafe path'):r.safe_input(self.root,'../outside')

if __name__=='__main__':unittest.main()
