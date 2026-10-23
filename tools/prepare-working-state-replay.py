#!/usr/bin/env python3
"""Prepare a disposable package that executes exact platform-neutral app state.
This is not an Apple SDK build and does not replace hosted app/device tests.
"""
import pathlib, shutil, sys
root = pathlib.Path(__file__).resolve().parents[1]
destination = pathlib.Path(sys.argv[1]).resolve()
if destination.exists():
    raise SystemExit('Choose a new disposable directory; existing files are never replaced.')
shutil.copytree(root / 'BlindCore', destination,
                ignore=shutil.ignore_patterns('.build', '.swiftpm', 'Package.resolved'))
source = (root / 'ios/BlindAssist/LocalImageAssistant.swift').read_text()
start = source.index('struct CompanionTaskUpdate:')
end = source.index('\n#if canImport(FoundationModels)', start)
(destination / 'Sources/BlindCore/ExtractedAppWorkingState.swift').write_text('import Foundation\n' + source[start:end])
tests = (root / 'ios/BlindAssistTests/CommunityTests.swift').read_text()
start = tests.index('final class CompanionWorkingStateTests:')
end = tests.index('\n/// EgoBlind-style', start)
(destination / 'Tests/BlindCoreTests/ExtractedAppWorkingStateTests.swift').write_text('import XCTest\n@testable import BlindCore\n' + tests[start:end])
print('Prepared exact app working-state source and tests. Run swift test --package-path ' + str(destination) + ' --filter CompanionWorkingStateTests -j 2')
