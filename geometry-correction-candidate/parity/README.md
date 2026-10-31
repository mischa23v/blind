# Full same-export numerical comparator — prepared, not native-validated

Current commit12a0b64 native run40738486723 was skipped by the repository visibility guard. No new native geometry capture exists, so this directory makes no new parity claim.

`inspect_public_usdz_full.py` is an isolated copy of the previously executed official OpenUSD wrapper, adding only complete local/world position and face-topology output. It retains original manifest/source/USDZ/metadata/inventory hashes, external-layer rejection, unit policy and resource checks. Original frozen wrapper is untouched.

`compare_full_mesh.py` compares the exact feature UUID sets, local/world transform matrices, local/world vertex multisets and local/world oriented triangle multisets. It preserves multiplicity and uses complete bipartite matching (not nearest-neighbour deduplication). Cyclic triangle rotations are equivalent; reversal is not. Numerical allowance is exactly the adapter's existing64*Float32epsilon*max(1,abs(value)) rule, not a physical clearance tolerance. Gf row-major row-vector matrices and Apple column-major column-vector matrices flatten to the same sequence for equivalent transforms.

No axis change, scale adjustment, origin repair, remeshing, triangulation or obstacle edits. Multiple meshes per UUID, nontriangular faces, subdivision surfaces, hole faces, left-handed meshes, altered unit conventions, incomplete capture or hash identity mismatch are rejected rather than guessed. Real fixtures currently have one mesh per feature.

21 synthetic comparator tests pass. The expanded official reader was also smoke-tested on the OLD run40726507227 exact unchanged public fixture assets: Hallway2(13meshes), Bedroom3(11meshes). `*-oldrun-full-reference.json` records those old upstream reads only. That inventory lacks new meshParity capture, deliberately preventing full native comparison. No synthetic replacement is substituted for native evidence.

After an approved real native run: obtain hash-verified bounded artifacts using existing extractor; run the expanded reader with the new manifest hash and exact new native assets; then pass its reference report and byte-identical native inventory to comparator. Keep original raw capture distinct from corrected historical floor-support route representation. Success is importer agreement, not real-world navigation safety or physical floor certainty.
