# Coffee tabletop representation diagnostic

Source-only diagnostic of the unchanged original MuSHRoom Coffee Polycam mesh, following the reproduced72-query native baseline. Full evidence/qualifications in TABLE_ISSUE_READBACK.md. This is not a successful physical path or a mapper correction.

Source: Xuqian Ren et al., [MuSHRoom iPhone Basic Data](https://zenodo.org/records/10230733), CC BY4.0. Original mesh/texture come from the checksum-verified `coffee_room_iphone.tar.gz`; source hashes and candidate-floor provenance are retained in TABLE_REPRESENTATION_RESULT.json. Source code is exact executed diagnostic code; paths are logical sibling artifact directories, not machine-private locations. No raw photos, texture, mesh, arrays or generated images are included here.

`table_issue.py` expects caller-local sibling `coffee-native-replay-prepared-002/` (unchanged originalOBJ, actual RESULT, orientation audit) and `coffee-semantic-coverage/` (selected originaltexture). It uses existing NumPy/Pillow/Matplotlib only;30CPU/512MiB caps are embedded. It does not query a planner, alter geometry or fit photo alignment. Original MTL was inspected separately to verify texture filename. The two source-space windows are debug neighborhoods, not calibrated table footprints. Preserve them unchanged on replay.

The full87,370-triangle bbox/height check finds no triangles spanning candidatefloor+0.45…1.10m in either window; this is stronger than absence from a centroid-filtered illustration. Actual photos contain tables, and textured mesh context supports a representation issue, but precise tabletop correspondence/physical collision is not established. Missing-table geometry could mislead both the native planner and a same-mesh collision oracle. The current longest route intersects one candidate window; that arithmetic is retained separately and is not measured table contact.

No new native execution, input mutation, data download, geometry repair or navigation authority. Source runtime generated an internal figure; its digest is preserved, but that figure is not included in this publication packet. Root owns publication.
