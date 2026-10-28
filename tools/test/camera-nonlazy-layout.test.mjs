// Source contracts only. Native layout, hit testing, VoiceOver and audits remain required.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const read = p => fs.readFileSync(new URL('../../'+p, import.meta.url), 'utf8');
const source = read('ios/BlindAssist/DashboardView.swift');
const baseline = read('research/camera-nonlazy-candidate-20261028/DashboardView.before.swift.txt');
const monitor = s => s.slice(s.indexOf('    private var monitor:'), s.indexOf('    /// Ask about'));
function assertContainer(s) {
 const m = monitor(s);
 assert.match(m,/ScrollView \{\s+VStack\(alignment: \.leading, spacing: 20\) \{/);
 assert.doesNotMatch(m,/\bForm\s*\{|LazyVStack|LazyVGrid|\.id\(|dynamicTypeSize|minimumScaleFactor|accessibilityHidden|accessibilityElement/);
 assert.match(m,/\.buttonStyle\(CameraControlButtonStyle\(\)\)/);
 assert.match(m,/\.navigationTitle\(t\("Camera and safety", "الكاميرا والسلامة"\)\)/);
}
test('only reviewed monitor, diagnostic entry and question prompt differ from published8767fa0',()=>{
 assertContainer(source);
 // Compare all three original Section closures verbatim apart from indentation.
 const sections = s => { const m=monitor(s); const a=m.indexOf('Section {'); const b=m.indexOf('\n        }\n        .navigationTitle'); return s===baseline ? m.slice(a,b).trim().split('\n').map(x=>x.trim()).join('\n') : m.slice(a,m.indexOf('\n            }\n            .frame(maxWidth:')).trim().split('\n').map(x=>x.trim()).join('\n'); };
 assert.equal(sections(source),sections(baseline));
 const strip = s => s.replace(/\/\/\/ Camera-only buttons[\s\S]*?(?=\/\/\/ The child's first tab)/,'').replace(monitor(s),'');
 const entry=read('research/recorder-entry-access-20261028/rooms-entry.swift.txt');
 assert.equal(source.split(entry).length,2); // Exact independently scoped addition, not a broad exclusion.
 const prompt=JSON.parse(read('research/ask-contrast-review-20261028/prompt-delta.json'));
 assert.equal(source.split(prompt.after).length,2); // Exact reviewed prompt-only delta.
 assert.equal(strip(source.replace(entry,'').replace(prompt.after,prompt.before)),strip(baseline));
 for(const [a,b] of [['ScrollView {','Form {'],['VStack(alignment: .leading, spacing: 20)','LazyVStack(alignment: .leading, spacing: 20)'],['.buttonStyle(CameraControlButtonStyle())','']]) {
  const m=monitor(source).replace(a,b); assert.throws(()=>assertContainer(source.replace(monitor(source),m)));
 }
});
test('camera button style grows naturally and supplies44pt minimum targets without replacing Buttons',()=>{
 const style=source.slice(source.indexOf('private struct CameraControlButtonStyle:'),source.indexOf("/// The child's first tab"));
 assert.match(style,/: ButtonStyle/);
 assert.match(style,/configuration\.label\s*\.frame\(minWidth: 44, minHeight: 44, alignment: \.leading\)/);
 assert.match(style,/\.frame\(maxWidth: \.infinity, alignment: \.leading\)/);
 assert.match(style,/\.contentShape\(Rectangle\(\)\)/);
 assert.match(style,/@Environment\(\\.isEnabled\)/);
 assert.match(style,/configuration\.isPressed/);
 assert.doesNotMatch(style,/maxHeight|frame\(height|lineLimit|minimumScaleFactor|onTapGesture|\.font\(/);
 assert.equal((source.match(/\.buttonStyle\(CameraControlButtonStyle\(\)\)/g)||[]).length,1);
});

test('Rooms diagnostic works without any saved room and never starts capture',()=>{
 const entry=read('research/recorder-entry-access-20261028/rooms-entry.swift.txt');
 const places=source.slice(source.indexOf('    private var places:'),source.indexOf('    private var places:')+7000);
 assert.match(entry,/model\.makeNavigationTestRecordingView\(\)/);
 assert.match(entry,/accessibilityIdentifier\("navigation-test-open"\)/);
 assert.match(entry,/disabled\(model\.places\.scanning\)/);
 assert.doesNotMatch(entry,/ForEach|startCamera|configureSession|cameraAwareness\s*=|startNavigationTestRecording/);
 assert.ok(places.indexOf(entry)>places.indexOf('.onDelete'));
 assert.ok(places.indexOf(entry)<places.indexOf('Section(t("Scan a new room"'));
});
