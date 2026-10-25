import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const base = process.env.DOCUMENT_SOURCE_ROOT ? pathToFileURL(process.env.DOCUMENT_SOURCE_ROOT + '/') : new URL('../../', import.meta.url);
const read = path => readFile(new URL(path, base), 'utf8');
const section = (s, a, b) => {
  const start = s.indexOf(a); assert.ok(start >= 0, a);
  const end = s.indexOf(b, start + a.length); assert.ok(end > start, b);
  return s.slice(start, end);
};

test('PDF adapter acquires only the explicit security-scoped file under balanced access', async () => {
  const s = await read('ios/BlindAssist/SelectedDocumentPDFAdapter.swift');
  const load = section(s, 'static func loadSelectedURL(', 'private static func readBoundedBytes(');
  assert.match(load, /guard url\.isFileURL, url\.startAccessingSecurityScopedResource\(\)/);
  assert.match(load, /defer \{ url\.stopAccessingSecurityScopedResource\(\) \}/);
  assert.ok(load.indexOf('defer { url.stopAccessingSecurityScopedResource() }') < load.indexOf('NSFileCoordinator()'));
  assert.match(load, /coordinate\(readingItemAt: url/);
  assert.match(load, /readBoundedBytes\(coordinatedURL\)/);
  assert.doesNotMatch(s, /URLSession|bookmarkData|UserDefaults|JSONEncoder|\.write\(|print\(|NSLog|localizedDescription|lastPathComponent|pathExtension/);
});

test('whole encoded input is rejected at bound plus one, never prefix parsed', async () => {
  const s = await read('ios/BlindAssist/SelectedDocumentPDFAdapter.swift');
  const bounded = section(s, 'private static func readBoundedBytes(', 'static func select(bytes:');
  assert.match(s, /maximumEncodedBytes = 20 \* 1024 \* 1024/);
  assert.match(bounded, /defer \{ try\? handle\.close\(\) \}/);
  assert.match(bounded, /maximumEncodedBytes \+ 1 - bytes\.count/);
  assert.match(bounded, /bytes\.count <= maximumEncodedBytes else \{ throw Failure\.oversizedInput \}/);
  assert.doesNotMatch(bounded, /prefix\(|PDFDocument\(/);
  assert.match(s, /SHA256\.hash\(data: bytes\)/);
});

test('PDF selection owns a bounded deep copy before parse hash and retention', async () => {
  const s = await read('ios/BlindAssist/SelectedDocumentPDFAdapter.swift');
  const select = section(s, 'static func select(bytes:', 'static func readPage(');
  assert.ok(select.indexOf('bytes.count <= maximumEncodedBytes') < select.indexOf('bytes.withUnsafeBytes'));
  assert.ok(select.indexOf('guard !bytes.isEmpty') < select.indexOf('bytes.withUnsafeBytes'));
  assert.match(select, /let frozen = bytes\.withUnsafeBytes \{ raw in\s*Data\(bytes: raw\.baseAddress!, count: raw\.count\)/);
  assert.ok(select.indexOf('Data(bytes: raw.baseAddress!, count: raw.count)') < select.indexOf('accessibleDocument(frozen)'));
  assert.match(select, /Selection\(bytes: frozen, sha256: digest\(frozen\)/);
  assert.doesNotMatch(select, /accessibleDocument\(bytes\)|digest\(bytes\)|Selection\(bytes: bytes/);
});

test('selection and explicit page extraction are separate and accessibility permission is not copying', async () => {
  const s = await read('ios/BlindAssist/SelectedDocumentPDFAdapter.swift');
  const select = section(s, 'static func select(bytes:', 'static func readPage(');
  assert.doesNotMatch(select, /page\(at:|page\.string|document\.string/);
  const page = section(s, 'static func readPage(', 'private static func accessibleDocument(');
  assert.match(page, /number > 0, number <= selection\.pageCount/);
  assert.match(page, /document\.page\(at: number - 1\)/);
  assert.match(page, /let text = page\.string/);
  assert.match(page, /throw Failure\.noReadableTextLayer/);
  assert.match(page, /text\.utf8\.count <= maximumPageUTF8Bytes else \{ throw Failure\.oversizedPage \}/);
  assert.doesNotMatch(page, /prefix\(|Vision|OCRRequest|unlock/);
  const permissions = section(s, 'private static func accessibleDocument(', 'private static func digest(');
  assert.match(permissions, /guard !document\.isLocked else \{ throw Failure\.locked \}/);
  assert.match(permissions, /guard document\.allowsContentAccessibility else \{ throw Failure\.accessibilityPermissionDenied \}/);
  assert.doesNotMatch(permissions, /guard.*allowsCopying|unlock\(/);
});

test('delegate owns a single result or cancel; dismiss is not guessed cancellation', async () => {
  const s = await read('ios/BlindAssist/SelectedDocumentPicker.swift');
  assert.match(s, /forOpeningContentTypes: \[\.pdf\], asCopy: false/);
  assert.match(s, /allowsMultipleSelection = false/);
  assert.match(s, /picker\.delegate = context\.coordinator/);
  assert.match(s, /didPickDocumentsAt urls: \[URL\]/);
  assert.match(s, /func documentPickerWasCancelled\(/);
  assert.equal((s.match(/guard !resolved else \{ return \}/g) ?? []).length, 2);
  assert.match(s, /onPicked\(ownerID, url\)/);
  assert.match(s, /onCancelled\(ownerID\)/);
  assert.doesNotMatch(s, /onDismiss|onDisappear|Task\.sleep|asyncAfter|fileImporter|bookmark/);
});

test('native fixture tests generate real PDF bytes rather than injecting extracted page records', async () => {
  const s = await read('ios/BlindAssistTests/SelectedDocumentPDFTests.swift');
  for (const label of ['EnglishActualBytes', 'ArabicAndMixedNumerals', 'ExplicitPageIndex', 'ImageOnly', 'MalformedAndWholeOversize', 'OversizedPageText', 'LockedPDF', 'AccessibilityPermissionNotCopyPermission', 'ColumnsAndTable', 'SourceReplacement', 'NSMutableDataAlias']) {
    assert.ok(s.includes('func test' + label), label);
  }
  assert.match(s, /UIGraphicsPDFRenderer/);
  assert.match(s, /dataRepresentation\(options:/);
  assert.match(s, /\.allowsContentAccessibility/);
  assert.match(s, /\.allowsContentCopying/);
  assert.match(s, /SelectedDocumentPDFAdapter\.readPage/);
  assert.match(s, /private enum PDFFixtures/);
  assert.doesNotMatch(s, /SelectedDocumentPDFTests\(\)|CompanionReferenceBlock\(|XCTSkip|\.write\(/);
});
