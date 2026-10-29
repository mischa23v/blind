#!/usr/bin/env python3
"""Verify exact macOS XCTest fixtures; Swift Testing's separate zero suite is not evidence."""
import argparse, json, re
from pathlib import Path

def require(value, message):
    if not value:
        raise ValueError(message)

EXPECTED_CASES = ['testAscendingStepStaircaseAndWallFirst', 'testFlatAndRampCounterexample', 'testAngleBoundaryNeighborhoods', 'testDescendingDropFourFrames', 'testCooldown179180BoundaryWithAccumulation', 'testMissingFloorOcclusionAndUnknownDoNotCount', 'testGapReplayAndPoseJitterReset', 'testInvalidGravityFrameAndDegenerateSegments', 'testFloorMedianWindowAndFixedWorldOrigin', 'testPairTiltAndSpanBoundaryNeighborhoods', 'testEndpointConventionIsExplicitAndChangesResult', 'testAscendingIsRawNoInheritedTemporalMarker', 'testMismatchedHitIdentityCannotBecomeObserved', 'testCadenceDiagnosticNominalDifferentAndUnknown', 'testCadenceToleranceIsExperimentalAndCounterNotTimeNormalized', 'testFiniteExtremeFloorMeanOverflowIsExplicitUnknown', 'testFiniteExtremeFloorVarianceAndProjectionOverflowAreUnknown']

def collect(source, log, command, before, after):
    expected=re.findall(r'^\s*func (test\w+)\(', source, re.M)
    require(expected==EXPECTED_CASES and len(set(expected))==17, 'expected exact reviewed 17-fixture XCTest source')
    case_lines=[line for line in log.splitlines() if line.startswith('Test Case ')]
    pattern=r"Test Case '-\[([^ ]+) (test\w+)\]' (started|passed|failed|skipped)(?:\.| \([^\n]*\)\.)"
    observed={}
    for line in case_lines:
        match=re.fullmatch(pattern,line)
        require(match is not None, 'unrecognized XCTest case record')
        cls,name,status=match.groups()
        require(cls=='PaperStairReferenceTests.ReferenceTests', 'unexpected XCTest class')
        observed.setdefault(name,[]).append(status)
    require(observed=={name:['started','passed'] for name in expected}, 'missing, extra, duplicate, failed or skipped XCTest cases')
    suite_lines=[line for line in log.splitlines() if line.startswith('Test Suite ')]
    suites={}
    for line in suite_lines:
        match=re.fullmatch(r"Test Suite '([^']+)' (started|passed|failed) at .+\.",line)
        require(match is not None, 'unrecognized XCTest suite record')
        name,status=match.groups();suites.setdefault(name,[]).append(status)
    require(suites=={name:['started','passed'] for name in ['All tests','PaperStairReferencePackageTests.xctest','ReferenceTests']}, 'missing, extra, contradictory or failed XCTest suite')
    totals=re.findall(r'Executed (\d+) tests?, with (\d+) failures? \((\d+) unexpected\)',log)
    require(len(totals)==3 and all(t==('17','0','0') for t in totals), 'missing or contradictory XCTest totals')
    require(command.get('swift_test_exit_code')==0 and command.get('log_writer_exit_code')==0, 'command failed')
    require(before==after=='', 'source not clean before and after test')
    return {'status':'passed','scope':'17 macOS synthetic XCTest fixtures, not live sensing','executed':17,'passed':17,'failed':0,'cases':[{'name':n,'status':'passed'} for n in expected],'swift_testing_zero_suite_not_counted':True,'source_clean_before_and_after':True}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('source',type=Path);parser.add_argument('artifact_dir',type=Path);args=parser.parse_args();d=args.artifact_dir
    result=collect(args.source.read_text(),(d/'swift-test.log').read_text(),json.loads((d/'result.json').read_text()),(d/'source-before.txt').read_text(),(d/'source-after.txt').read_text())
    (d/'xctest-results.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
