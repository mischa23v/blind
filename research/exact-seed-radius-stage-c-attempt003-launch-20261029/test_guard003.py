"""Portable filesystem/fake-state checks only: no Guard init, process, or compiler."""
import copy,json,os,pathlib,sys,tempfile,time,types,unittest
from unittest.mock import patch
sys.dont_write_bytecode=True
from mac_guard import (Guard,GuardFailure,output_bytes,controlled_reason,remember_failure,
                       child_environment,failure_event)
from launch_stage_c import finalize_public_aggregate,retain_first_failure,resolve_argument
from failure_evidence import failure_evidence

class Guard003Fixtures(unittest.TestCase):
    def fixture(self,root,absolute=False):
        cache=root/'module-cache'/'HASH';cache.mkdir(parents=True)
        target=cache/'Foundation-ABC.pcm.lock-0123abcd';target.write_bytes(b'owner 123')
        link=cache/'Foundation-ABC.pcm.lock';link.symlink_to(target if absolute else target.name)
        return cache,target,link
    def refused(self,root,code):
        with self.assertRaises(GuardFailure) as caught:output_bytes(root)
        self.assertEqual(controlled_reason(caught.exception),code)
        return caught.exception
    def test_relative_and_absolute_llvm_file_locks_count_link_not_target_twice(self):
        for absolute in [False,True]:
            with tempfile.TemporaryDirectory() as d:
                root=pathlib.Path(d);_,target,link=self.fixture(root,absolute)
                self.assertEqual(output_bytes(root),target.stat().st_size+link.lstat().st_size)
                link.unlink();self.assertEqual(output_bytes(root),target.stat().st_size)
                target.unlink();self.assertEqual(output_bytes(root),0)
    def test_dangling_same_directory_lock_is_not_followed(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);_,target,link=self.fixture(root,True);target.unlink()
            self.assertEqual(output_bytes(root),link.lstat().st_size)
    def test_lock_unlinked_between_lstat_and_readlink_is_tolerated(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);_,target,link=self.fixture(root)
            def removed(name,**kwargs):link.unlink();raise FileNotFoundError()
            with patch('mac_guard.os.readlink',side_effect=removed):
                self.assertEqual(output_bytes(root),target.stat().st_size)
    def test_unique_lock_unlinked_after_listing_is_tolerated(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);_,target,link=self.fixture(root);link.unlink();original=os.stat
            def removed(name,*args,**kwargs):
                if name==target.name and kwargs.get('follow_symlinks') is False:
                    target.unlink();raise FileNotFoundError()
                return original(name,*args,**kwargs)
            with patch('mac_guard.os.stat',side_effect=removed):self.assertEqual(output_bytes(root),0)
    def test_absolute_and_relative_escapes_refused(self):
        for target in ['/tmp/private/Foundation-ABC.pcm.lock-0123abcd','../Foundation-ABC.pcm.lock-0123abcd','nested/Foundation-ABC.pcm.lock-0123abcd']:
            with tempfile.TemporaryDirectory() as d:
                root=pathlib.Path(d);_,file,link=self.fixture(root);link.unlink();link.symlink_to(target)
                self.refused(root,'OUTPUT_LINK_ESCAPE')
    def test_symlink_chain_and_loop_refused_without_traversal(self):
        for loop in [False,True]:
            with tempfile.TemporaryDirectory() as d:
                root=pathlib.Path(d);_,target,link=self.fixture(root);target.unlink()
                target.symlink_to(link.name if loop else '/tmp/external')
                with self.assertRaises(GuardFailure) as caught:output_bytes(root)
                self.assertIn(controlled_reason(caught.exception),{'OUTPUT_LINK_TARGET_TYPE','OUTPUT_LINK_NAME'})
    def test_directory_target_refused_even_with_correct_lock_name(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);_,target,link=self.fixture(root);target.unlink();target.mkdir()
            self.refused(root,'OUTPUT_LINK_TARGET_TYPE')
    def test_unknown_scope_and_nonlock_names_remain_refused(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'cache').mkdir();(root/'cache'/'a.lock').symlink_to('a.lock-0123abcd')
            self.refused(root,'OUTPUT_LINK_SCOPE')
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'module-cache').mkdir();(root/'module-cache'/'other').symlink_to('other-0123abcd')
            self.refused(root,'OUTPUT_LINK_NAME')
    def test_cache_directory_symlink_refused(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'actual').mkdir();(root/'module-cache').symlink_to('actual',target_is_directory=True)
            self.refused(root,'OUTPUT_LINK_SCOPE')
    def test_actual_recipe_cache_path_contract_with_absolute_target(self):
        here=pathlib.Path(__file__).resolve().parent
        recipe=json.loads((here.parent/'exact-seed-radius-bc-preparation-20261029/prepared-stage-c-final/BUILD_RECIPE.json').read_text())
        command=next(x for x in recipe['commands'] if x['label']=='swift-probe-compile')
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d).resolve()/'blind-exact-seed-radius-stage-c-attempt003';root.mkdir()
            roots={'@build':root,'@packet':root/'packet','@repository':root/'repo','@sdk':root/'sdk'}
            argv=[resolve_argument(x,roots) for x in command['argv']]
            argv[2:2]=['-module-cache-path',str(root/'module-cache')]
            self.assertIn("argv[2:2]=['-module-cache-path',str(output/'module-cache')]",(here/'launch_stage_c.py').read_text())
            env=child_environment(root,{})
            self.assertEqual(argv[3],env['CLANG_MODULE_CACHE_PATH']);self.assertEqual(argv[3],env['SWIFT_MODULECACHE_PATH'])
            _,target,link=self.fixture(root,True)
            self.assertEqual(output_bytes(root),target.stat().st_size+link.lstat().st_size)
    def test_first_monitor_failure_survives_later_failure(self):
        fake=types.SimpleNamespace(records=[{'index':1}],firstFailure=None,secondaryFailures={})
        def failing():raise GuardFailure('output symlink scope',{'outputScope':'owned-output','entryKind':'symlink'})
        fake._observe=failing
        with self.assertRaises(GuardFailure):Guard.monitor(fake)
        first=copy.deepcopy(fake.firstFailure)
        remember_failure(fake,GuardFailure('aggregate CPU cap'),'terminal-export',secondary=True)
        self.assertEqual(fake.firstFailure,first);self.assertEqual(first['reasonCode'],'OUTPUT_LINK_SCOPE')
        self.assertEqual(fake.secondaryFailures['terminal-export']['reasonCode'],'CPU_LIMIT')
    def test_cleanup_and_save_failures_do_not_replace_first_command_refusal(self):
        def cleanup():raise GuardFailure('child retirement not confirmed')
        def save():raise OSError(5,'private details')
        fake=types.SimpleNamespace(records=[],failure=None,retire=cleanup,save=save)
        with self.assertRaises(GuardFailure) as caught:Guard.run(fake,['never-executed'],'../bad')
        self.assertEqual(controlled_reason(caught.exception),'COMMAND_LABEL_REFUSED')
        self.assertEqual(fake.firstFailure['reasonCode'],'COMMAND_LABEL_REFUSED')
        self.assertEqual(fake.secondaryFailures['retirement']['reasonCode'],'RETIREMENT_UNCONFIRMED')
        self.assertEqual(fake.secondaryFailures['command-finalization']['reasonCode'],'FILESYSTEM_ERROR')
    def test_observed_nonzero_exit_precedes_post_exit_monitor_failure(self):
        with tempfile.TemporaryDirectory() as d:
            calls=[]
            def monitor():
                calls.append(1)
                if len(calls)==3:raise GuardFailure('ps columns changed')
                return {}
            fake=types.SimpleNamespace(out=pathlib.Path(d),cwd=pathlib.Path(d),records=[],failure=None,
              firstFailure=None,secondaryFailures={},monitor=monitor,retire=lambda:None,save=lambda:None,
              maximumCPU=0,cpuLimit=120,outputLimit=134217728,environment={},groups=set(),seen={})
            process=types.SimpleNamespace(pid=999999,returncode=7,poll=lambda:7)
            # Constructor is replaced: no child, preexec_fn, signals, or native work.
            with patch('mac_guard.subprocess.Popen',return_value=process):
                with self.assertRaises(GuardFailure):Guard.run(fake,['not-executed'],'swift-probe-compile')
            self.assertEqual(fake.firstFailure['reasonCode'],'COMMAND_EXIT_NONZERO')
            self.assertEqual(fake.secondaryFailures['command-finalization']['reasonCode'],'PS_COLUMNS')
            self.assertEqual(fake.records[0]['exitCode'],7)
    def test_wrapped_filesystem_error_retains_only_bounded_errno(self):
        try:
            try:raise OSError(13,'private /Users/path')
            except OSError as cause:raise GuardFailure('output scan unavailable') from cause
        except GuardFailure as error:event=failure_event(error,'guard-monitor')
        self.assertEqual(event['reasonCode'],'OUTPUT_SCAN_UNAVAILABLE');self.assertEqual(event['metadata']['errno'],13)
        self.assertNotIn('/Users',json.dumps(event))
    def test_first_failure_keeps_original_phase_command_and_metadata(self):
        rows=[{'index':1,'label':'swift-probe-compile','processStarted':True,'processCompleted':True,'exitCode':-9,'reasonCode':'OUTPUT_LINK_SCOPE'},
              {'index':2,'label':'repository-head-after','processStarted':True,'processCompleted':True,'exitCode':0,'reasonCode':None}]
        fake=types.SimpleNamespace(records=rows[:1],firstFailure=None,secondaryFailures={})
        error=GuardFailure('output symlink scope',{'outputScope':'module-cache','entryKind':'symlink','secret':'ignored'})
        remember_failure(fake,error,'guard-monitor');record={}
        retain_first_failure(record,fake,error,'swift-compile');fake.records=rows
        retain_first_failure(record,fake,GuardFailure('aggregate CPU cap'),'terminal-export',secondary='terminal-export')
        recipe={'commands':[{'label':'swift-probe-compile'}]}
        row=failure_evidence(record,fake,recipe,{},pathlib.Path('/unused'))
        self.assertEqual((row['phase'],row['guardCommandIndex'],row['commandLabel'],row['reasonCode']),('swift-compile',1,'swift-probe-compile','OUTPUT_LINK_SCOPE'))
        self.assertEqual(row['safeMetadata'],{'outputScope':'module-cache','entryKind':'symlink','errno':None})
        self.assertEqual(row['secondaryFailureCodes']['terminal-export'],'CPU_LIMIT')
    def test_failed_finalization_exports_last_sample_not_terminal_resources(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'untrusted-link').symlink_to('/outside')
            sample={'sampleIndex':7,'wallSeconds':3.,'observedAggregateCPUSeconds':2.,'observedPeakRSSBytes':1000,'observedPeakOutputBytes':20,'completeTerminalObservation':False,'capComplianceEstablished':False}
            def finish():raise GuardFailure('output symlink scope')
            fake=types.SimpleNamespace(started=time.monotonic(),maximumCPU=2.,maximumRSS=1000,maximumOutput=20,lastValidSample=sample,finish=finish,save=lambda:None,records=[],firstFailure=None,secondaryFailures={})
            record={'status':'failed-or-inconclusive'};error=GuardFailure('aggregate CPU cap')
            retain_first_failure(record,fake,error,'swift-compile')
            builder=lambda:failure_evidence(record,fake,None,{},root)
            encoded,final_error=finalize_public_aggregate(root,{'status':record['status']},fake,record,lambda:None,builder)
            value=json.loads(encoded)
            self.assertIsNotNone(final_error);self.assertEqual(value['status'],'failed-or-inconclusive')
            self.assertNotIn('resources',value);self.assertEqual(value['lastValidResourceSample'],sample)
            self.assertEqual(value['failureEvidence']['reasonCode'],'CPU_LIMIT')
            self.assertEqual(value['failureEvidence']['secondaryFailureCodes']['terminal-export'],'OUTPUT_LINK_SCOPE')
            self.assertEqual(json.loads((root/'AGGREGATE.review-required.json').read_text()),value)
    def test_first_terminal_failure_cannot_leave_passed_artifact(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'bad').symlink_to('/outside')
            fake=types.SimpleNamespace(started=time.monotonic(),maximumCPU=1.,maximumRSS=10,maximumOutput=0,finish=lambda:None,records=[],firstFailure=None,secondaryFailures={})
            record={'status':'passed-fixed-source-route-matrix'}
            encoded,error=finalize_public_aggregate(root,{'status':record['status']},fake,record,lambda:None,lambda:failure_evidence(record,fake,None,{},root))
            value=json.loads(encoded);self.assertIsNotNone(error);self.assertEqual(value['status'],'failed-or-inconclusive')
            self.assertEqual(value['failureEvidence']['reasonCode'],'OUTPUT_LINK_SCOPE');self.assertNotIn('resources',value)
    def test_guard_invariants_have_specific_codes_and_no_raw_metadata(self):
        messages=['unexpected ps stderr','invalid ps CPU field','invalid ps CPU range','nonfinite CPU','ps output cap','ps columns changed','invalid ps identity','ps row cap','guard missing from ps','process-family traversal failed','output file-count cap','output symlink scope','output symlink target escape','output symlink target type','output scan unavailable']
        for message in messages:self.assertNotEqual(controlled_reason(GuardFailure(message)),'VALIDATION_REFUSED')
        event=failure_event(OSError(5,'secret /Users/private/path'),'retirement')
        self.assertEqual(event['metadata']['errno'],5);self.assertNotIn('secret',json.dumps(event))

if __name__=='__main__':unittest.main(verbosity=2)
