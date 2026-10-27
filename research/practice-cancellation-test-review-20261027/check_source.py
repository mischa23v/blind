#!/usr/bin/env python3
"""Narrow exact-source contracts, not Swift execution or a general semantic parser.

Rejects unreviewed changes, including call movement into deferred/dead branches.
The expected snippets are reviewed data, not regenerated during checking.
"""
import json
from pathlib import Path
import re

H = Path(__file__).resolve().parent
R = H.parents[1]
EXPECTED = json.loads((H / 'SOURCE_CONTRACT.json').read_text())

def compact(value):
    return re.sub(r'\s+', ' ', value).strip()

def regions(dashboard, model):
    end = dashboard.index('.accessibilityIdentifier("home-practice")') + len('.accessibilityIdentifier("home-practice")')
    start = dashboard.rfind('                Button(t("Try practice (2 minutes)",', 0, end)
    assert start >= 0
    home = dashboard[start:end]
    end = dashboard.index('.accessibilityIdentifier("start-simulation")') + len('.accessibilityIdentifier("start-simulation")')
    start = dashboard.rfind('                    Button {', 0, end)
    assert start >= 0
    camera = dashboard[start:end]
    start = model.index('    func startSimulation() {')
    end = model.index('    /// Ends practice', start)
    return dict(home=home, camera=camera, startSimulation=model[start:end])

def validate(dashboard, model):
    actual = regions(dashboard, model)
    assert all(compact(actual[k]) == compact(EXPECTED[k]) for k in EXPECTED), 'unreviewed practice action/lifecycle change'
    # These are assertions about the exact approved bodies above; equality avoids
    # accepting a matching call hidden in an added if-false/Task/unused closure.
    assert '{ model.startSimulation(); selectedTab = "companion" }' in actual['home']
    assert 'Button { model.startSimulation() } label:' in actual['camera']
    body = compact(actual['startSimulation'])
    assert body.startswith('func startSimulation() { stopCameraMonitoring(); feedback.stop(includingAlerts: true) simulation = true; running = true; detector.beginCalibration()')
    assert 'Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in self?.endPractice() }' in body
    assert body.index('simulation = true; running = true') < body.index('Timer.scheduledTimer')

def validate_cancellation(tests):
    body = tests.split('    func testPracticeIsAnnouncedAndCanStop() {', 1)[1].split('    func testAccessibleMainModesAndOfflineDefault()', 1)[0]
    expected = [
        'let startedBeforeTap = ProcessInfo.processInfo.systemUptime',
        'let cancellationEvidenceLimit: TimeInterval = 90',
        'start.tap()',
        'XCTAssertTrue(app.staticTexts["SIMULATION · generated readings"].waitForExistence(timeout: 5))',
        'let end = app.buttons["end-practice"]',
        'reveal(end)',
        'XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - startedBeforeTap, cancellationEvidenceLimit,',
        'end.tap()',
        'XCTAssertFalse(app.staticTexts["SIMULATION · generated readings"].exists)',
        'XCTAssertEqual(app.buttons["monitor-toggle"].label, "Start monitoring")',
        'let elapsed = ProcessInfo.processInfo.systemUptime - startedBeforeTap',
        'XCTAssertLessThan(elapsed, cancellationEvidenceLimit,',
        'print("PRACTICE_CANCEL elapsedUpperBound=',
    ]
    cursor = 0
    for token in expected:
        assert body.count(token) == 1, 'missing or ambiguous cancellation token: ' + token
        cursor = body.index(token, cursor) + len(token)
    assert body.count('PRACTICE_CANCEL') == 1
    assert 'continueAfterFailure = false' in tests


def main():
    dashboard = (R / 'ios/BlindAssist/DashboardView.swift').read_text()
    model = (R / 'ios/BlindAssist/NavigationModel.swift').read_text()
    validate(dashboard, model)
    mutations = [
        ('home missing', dashboard.replace('{ model.startSimulation(); selectedTab', '{ selectedTab', 1), model),
        ('home deferred', dashboard.replace('{ model.startSimulation(); selectedTab', '{ Task { model.startSimulation() }; selectedTab', 1), model),
        ('home dead', dashboard.replace('{ model.startSimulation(); selectedTab', '{ if false { model.startSimulation() }; selectedTab', 1), model),
        ('home order reversed', dashboard.replace('{ model.startSimulation(); selectedTab = "companion" }', '{ selectedTab = "companion"; model.startSimulation() }', 1), model),
        ('camera missing', dashboard.replace('Button { model.startSimulation() } label:', 'Button { } label:', 1), model),
        ('camera deferred', dashboard.replace('Button { model.startSimulation() } label:', 'Button { Task { model.startSimulation() } } label:', 1), model),
        ('camera dead', dashboard.replace('Button { model.startSimulation() } label:', 'Button { if false { model.startSimulation() } } label:', 1), model),
        ('state missing', dashboard, model.replace('simulation = true; running = true; detector.beginCalibration()', 'detector.beginCalibration()', 1)),
        ('state deferred', dashboard, model.replace('simulation = true; running = true; detector.beginCalibration()', 'Task { simulation = true; running = true }; detector.beginCalibration()', 1)),
        ('state dead', dashboard, model.replace('simulation = true; running = true; detector.beginCalibration()', 'if false { simulation = true; running = true }; detector.beginCalibration()', 1)),
        ('expiry changed', dashboard, model.replace('Timer.scheduledTimer(withTimeInterval: 120, repeats: false)', 'Timer.scheduledTimer(withTimeInterval: 240, repeats: false)', 1)),
    ]
    for name, d, m in mutations:
        assert (d, m) != (dashboard, model), 'mutation did not change source: ' + name
        try:
            validate(d, m)
        except (AssertionError, ValueError):
            pass
        else:
            raise AssertionError('accepted mutation: ' + name)
    tests = (R / 'ios/BlindAssistUITests/LaunchTests.swift').read_text()
    validate_cancellation(tests)
    witness = '        print("PRACTICE_CANCEL elapsedUpperBound='
    witness_line = next(line for line in tests.splitlines(True) if line.startswith(witness))
    cancellation_mutations = [
        ('missing End tap', tests.replace('        end.tap()\n', '', 1)),
        ('missing active banner', tests.replace('        XCTAssertTrue(app.staticTexts["SIMULATION · generated readings"].waitForExistence(timeout: 5))\n', '', 1)),
        ('missing pre-End guard', tests.replace('XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - startedBeforeTap, cancellationEvidenceLimit,', 'XCTAssertTrue(true,', 1)),
        ('missing final guard', tests.replace('XCTAssertLessThan(elapsed, cancellationEvidenceLimit,', 'XCTAssertTrue(true,', 1)),
        ('raised limit', tests.replace('cancellationEvidenceLimit: TimeInterval = 90', 'cancellationEvidenceLimit: TimeInterval = 120', 1)),
        ('timestamp after Start', tests.replace('        let startedBeforeTap = ProcessInfo.processInfo.systemUptime\n', '', 1).replace('        start.tap()\n', '        start.tap()\n        let startedBeforeTap = ProcessInfo.processInfo.systemUptime\n', 1)),
        ('early witness', tests.replace(witness_line, '', 1).replace('        XCTAssertLessThan(elapsed, cancellationEvidenceLimit,', witness_line + '        XCTAssertLessThan(elapsed, cancellationEvidenceLimit,', 1)),
        ('missing stopped banner', tests.replace('        XCTAssertFalse(app.staticTexts["SIMULATION · generated readings"].exists)\n', '', 1)),
    ]
    for name, changed in cancellation_mutations:
        assert changed != tests, 'mutation did not change source: ' + name
        try:
            validate_cancellation(changed)
        except (AssertionError, ValueError, IndexError):
            pass
        else:
            raise AssertionError('accepted cancellation mutation: ' + name)
    print(json.dumps(dict(exactSourceContract=True, rejectedActionMutations=len(mutations),
        cancellationOrderContract=True, rejectedCancellationMutations=len(cancellation_mutations),
        swiftExecuted=False, nativeUIExecuted=False)))

if __name__ == '__main__':
    main()
