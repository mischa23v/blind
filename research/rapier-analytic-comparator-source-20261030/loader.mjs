/**
 * Not run. Importing this LOCAL loader does not import Rapier or initialize WASM.
 * Only an independently admitted supervised caller may call the exported function.
 */
import {readFile, lstat, realpath} from "node:fs/promises";
import {createHash} from "node:crypto";
import path from "node:path";
import {pathToFileURL} from "node:url";
const RECEIPT_SHA256 = "f49c4e18d4f3a8e4acd84575a7a6ee45c4bdf9dcef052b7c4d4bc597f40f01c6";
const sha = (b) => createHash("sha256").update(b).digest("hex");
function assert(ok, message) { if (!ok) throw new Error(message); }
async function regularNoSymlink(root, relative) {
  const parts = relative.split("/");
  assert(parts.length > 0 && parts.every(p => p && p !== "." && p !== ".."), "unsafe relative file path");
  let current = root;
  for (let i = 0; i < parts.length; ++i) {
    current = path.join(current, parts[i]);
    const st = await lstat(current);
    assert(!st.isSymbolicLink(), "symlink forbidden in frozen package");
    assert(i === parts.length - 1 ? st.isFile() : st.isDirectory(), "unexpected file kind");
  }
  return readFile(current);
}
export async function loadForAdmittedExecution(preparationRoot, admission) {
  assert(admission?.rootReviewed === true && admission?.aggregateSupervisorActive === true,
    "separate root review and aggregate supervisor are mandatory");
  const root = path.resolve(preparationRoot);
  assert(await realpath(root) === root, "preparation root may not be symlinked");
  const receiptBytes = await regularNoSymlink(root, "ACQUISITION_RECEIPT.json");
  assert(sha(receiptBytes) === RECEIPT_SHA256, "acquisition receipt identity changed");
  const receipt = JSON.parse(receiptBytes);
  assert(receipt.fileCount === 54 && receipt.unpackedBytes === 15038573, "package inventory mismatch");
  for (const file of receipt.files) {
    const b = await regularNoSymlink(root, file.path);
    assert(b.length === file.bytes && sha(b) === file.sha256, "frozen package file changed: " + file.path);
  }
  // The first import of official code and first WASM initialization are HERE,
  // not at module load, fixture generation, source review or metadata acquisition.
  const R = await import(pathToFileURL(path.join(root, "package/dist/rapier.mjs")).href);
  await R.init();
  // This is the JS wrapper crate's version, not the underlying core version.
  assert(R.version() === "0.21.0", "unexpected initialized JS/WASM version");
  assert(R.TriMeshFlags.FIX_INTERNAL_EDGES_TWO_SIDED === 656, "unexpected exported flags");
  return R;
}

