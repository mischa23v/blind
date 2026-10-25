// Source-bound synthetic state witness, not XCTest timing/runtime acceptance.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const source = readFileSync(new URL('../../ios/BlindAssistUITests/LaunchTests.swift', import.meta.url), 'utf8');
const reveal = source.slice(source.indexOf('    private func reveal('), source.indexOf('    override func setUpWithError'));
const settings = source.slice(source.indexOf('    private func openSettingsPage('), source.indexOf('    func testMainScreen'));
// Require the exact control structure represented by the state witness below.
test('actual Swift helpers match bounded early-break witness and retain assertion', () => {
 assert.match(reveal, /for _ in 0\.\.<8\s*\{\s*if element\.isHittable \{ break \}\s*app\.swipeUp\(\)\s*\}/);
 assert.match(reveal, /for _ in 0\.\.<8\s*\{\s*if element\.isHittable \{ break \}\s*app\.swipeDown\(\)\s*\}/);
 assert.match(reveal, /XCTAssertTrue\(element\.isHittable\)/);
 assert.match(settings, /for _ in 0\.\.<8\s*\{\s*if app\.buttons\["settings-details"\]\.exists \{ break \}\s*app\.navigationBars\.buttons\.element\(boundBy: 0\)\.tap\(\)\s*\}/);
 assert.match(settings, /reveal\(page\); page\.tap\(\)/);
 assert.doesNotMatch(reveal + settings, /sleep|timeout:|where !/);
});
function exerciseReveal({old = false, reachable = () => true}) {
 const state = {queries: 0, up: 0, down: 0};
 const query = () => { state.queries++; return reachable(state); };
 for (const direction of ['up', 'down']) {
  for (let i = 0; i < 8; i++) {
   if (query()) { if (!old) break; } else state[direction]++;
  }
 }
 return {...state, passed: query(), finalQueries: state.queries};
}
function exerciseSettings({old = false, reachable = () => true}) {
 const state = {queries: 0, taps: 0};
 for (let i = 0; i < 8; i++) {
  state.queries++;
  if (reachable(state)) { if (!old) break; } else state.taps++;
 }
 return state;
}
test('already-visible reveal reduces17queries to3 with no gestures', () => {
 const old = exerciseReveal({old:true}), next = exerciseReveal({});
 assert.equal(old.finalQueries,17); assert.equal(next.finalQueries,3);
 assert.equal(next.up+next.down,0); assert.equal(next.passed,true);
});
test('all stable up and down discovery positions preserve gesture counts and success', () => {
 for(let n=1;n<=8;n++) {
  for(const direction of ['up','down']) {
   const reachable = s => direction==='up' ? s.up>=n : s.up===8&&s.down>=n;
   const old=exerciseReveal({old:true,reachable}), next=exerciseReveal({reachable});
   assert.deepEqual([next.up,next.down,next.passed],[old.up,old.down,old.passed]);
   assert.ok(next.finalQueries<=old.finalQueries);
  }
 }
});
test('unreachable target keeps8up8down bound and fails final assertion', () => {
 const next=exerciseReveal({reachable:()=>false});
 assert.equal(next.up,8);assert.equal(next.down,8);assert.equal(next.passed,false);assert.equal(next.finalQueries,17);
});
test('state disappearance after early discovery cannot bypass final assertion', () => {
 const next=exerciseReveal({reachable:s=>s.queries<=2});
 assert.equal(next.passed,false);assert.equal(next.finalQueries,3);
});
test('state loss before second direction is handled within original down bound', () => {
 const next=exerciseReveal({reachable:s=>s.queries===1 || s.down>=2});
 assert.equal(next.up,0);assert.equal(next.down,2);assert.equal(next.passed,true);
});
test('settings already present reduces8reads to1 and no taps', () => {
 assert.deepEqual(exerciseSettings({old:true}),{queries:8,taps:0});
 assert.deepEqual(exerciseSettings({}),{queries:1,taps:0});
});
test('settings all discovery depths and missing state keep same navigation tap bounds', () => {
 for(let n=1;n<=9;n++) {
  const reachable=s=>s.taps>=n;
  const old=exerciseSettings({old:true,reachable}),next=exerciseSettings({reachable});
  assert.equal(next.taps,old.taps);assert.ok(next.queries<=old.queries);assert.ok(next.taps<=8);
 }
});
