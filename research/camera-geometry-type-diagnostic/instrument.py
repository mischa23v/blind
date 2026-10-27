#!/usr/bin/env python3
"""Only transforms exact source pins in an explicitly disposable checkout."""
from pathlib import Path
import hashlib

SOURCE = 'fb879d235f38a3f0121b69b023e8ee14c0ded61c'
PINS = {
 'ios/BlindAssist/DashboardView.swift': '7c1ee284cb9b0a73ccc64dd18128a82d1864b40b5d234af71f6d1a5680b0ac86',
 'ios/BlindAssistUITests/LaunchTests.swift': '7678df48b63dd78f3e8dabef81e7042dc821458db59749bcbc8ab585648de6e4',
 'ios/BlindAssistUITests/CameraAuditScopeTests.swift': 'ea5371aecc0303e15ac5ee9a1f80e0e76ae916db82f783888fa82c7f459fb1d8',
 'tools/ci/camera-audit-scope-control.py': '3b853a7caac35fc8d63cb206aa5260845cd198265a3d2599eb8e359331475550',
}

def instrument(root):
 root=Path(root)
 original={p:(root/p).read_text() for p in PINS}
 for p,sha in PINS.items():
  if hashlib.sha256((root/p).read_bytes()).hexdigest()!=sha:
   raise ValueError('Source pin mismatch: '+p)
 text=dict(original)
 def change(p,a,b):
  if text[p].count(a)!=1: raise ValueError('Nonunique instrumentation anchor: '+p)
  text[p]=text[p].replace(a,b)
 app,full,typed,runner=PINS
 change(app, '.accessibilityIdentifier("start-simulation")', '.accessibilityIdentifier("start-simulation")\n                    .modifier(AuditGeometryProbe(role: "button"))')
 # Exact header/footer boundary; existing text and font modifiers remain byte-identical.
 change(app, '''                    .multilineTextAlignment(.leading)
            } footer: {
                Text(t("Practice pauses''', '''                    .multilineTextAlignment(.leading)
                    .modifier(AuditGeometryProbe(role: "header"))
            } footer: {
                Text(t("Practice pauses''')
 change(app, '''                    .multilineTextAlignment(.leading)
            }
        }
        .navigationTitle(t("Camera and safety"''', '''                    .multilineTextAlignment(.leading)
                    .modifier(AuditGeometryProbe(role: "footer"))
            }
        }
        .navigationTitle(t("Camera and safety"''')
 change(app, '        .navigationTitle(t("Camera and safety",', '        .modifier(AuditGeometryProbe(role: "container"))\n        .navigationTitle(t("Camera and safety",')
 text[app]+=Path(__file__).with_name('GeometryTrace.swift.txt').read_text()
 for p in (full,typed):
  change(p, 'import XCTest', 'import XCTest\nimport CoreFoundation')
  change(p, 'app.launchArguments = ["--ui-testing",', 'app.launchArguments = ["--ui-testing", "--audit-geometry-type",')
  call='        try app.performAccessibilityAudit' + (' { issue in' if p==full else '(for: .dynamicType) { issue in')
  # LaunchTests also has a main-screen audit, so use the destination's unique observedFindings anchor.
  anchor='        var observedFindings = 0\n'+call
  prefix = """        var observedFindings = 0
        let previousContinueAfterFailure = continueAfterFailure
        continueAfterFailure = true
        var auditTermination = "threw"
        defer {
            print("ACCESSIBILITY_AUDIT_GEOMETRY_END phase=\\(phase) termination=\\(auditTermination) uptime=\\(ProcessInfo.processInfo.systemUptime)")
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(rawValue: "org.blindassist.synthetic.geometry.flush" as CFString), nil, nil, true)
            continueAfterFailure = previousContinueAfterFailure
        }
        print("ACCESSIBILITY_AUDIT_GEOMETRY_BEGIN phase=\\(phase) uptime=\\(ProcessInfo.processInfo.systemUptime)")
"""
  change(p, anchor, prefix + call)
  change(p, '            return element.identifier == "retrace-session" && !element.isEnabled\n        }\n    }',
         '            return element.identifier == "retrace-session" && !element.isEnabled\n        }\n        auditTermination = "returned"\n    }')
  change(p, '            print("ACCESSIBILITY_AUDIT=type:', '            print("ACCESSIBILITY_AUDIT_GEOMETRY_ISSUE phase=\\(phase) uptime=\\(ProcessInfo.processInfo.systemUptime)")\n            print("ACCESSIBILITY_AUDIT=type:')
 change(runner, '                code = run(base + [\'-only-testing:\'', '                case[\'traceNotBefore\'] = time.time()\n                code = run(base + [\'-only-testing:\'')
 change(runner, "                case['logSummary'] = bounded_log(name)", """                case['logSummary'] = bounded_log(name)
                try:
                    container = checked(['xcrun', 'simctl', 'get_app_container', device,
                                         'org.blindassist.mobility', 'data'], name + '-trace-container', 30).strip()
                    from geometry_trace_collector import collect
                    trace = collect(Path(container) / 'tmp' / 'blind-geometry-type-synthetic.jsonl',
                                    case.get('traceNotBefore'), artifacts / (name + '-geometry-type.json'), case['logSummary'])
                    case['geometryTypeTrace'] = trace
                except Exception as error:
                    case['geometryTypeTrace'] = {'status': 'failed', 'error': safe_error(error)}
                    failed = True""")
 # Validate all anchors/pins before writing anything.
 for p in PINS: (root/p).write_text(text[p])
 return {p:{'before':PINS[p], 'after':hashlib.sha256(text[p].encode()).hexdigest()} for p in PINS}
