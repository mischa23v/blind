# Public-fixture boundary for this diagnostic packet

Only two already published, hash-pinned **Apple sample prescanned-room models**
are admitted. Their room names describe Apple's sample models; they are not
scans of this user's home or captures supplied by a user/family/child.

| Apple sample member | Original CapturedRoom SHA256 |
|---|---|
| `RoomPlanMultiscanMerging/MyHome/Hallway2/capturedRoom.json` | `f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d` |
| `RoomPlanMultiscanMerging/MyHome/Bedroom3/capturedRoom.json` | `44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e` |

The existing repository provenance records extraction from Apple's
[Merging multiple scans into a single structure sample](https://developer.apple.com/documentation/roomplan/merging-multiple-scans-into-a-single-structure),
archive`https://developer.apple.com/tutorials/3e2b731b0ef7/MergingMultipleScansIntoASingleStructure.zip`,
SHA256`135cf2ae9c415723f9f32c31a130b4ce9efced61b3e22f50858785a4323d66a1`.
The original fixture README and Apple permission notice are retained here under
`provenance/`, fetched as immutable blobs from the existing public repository
and verified against their Git blob IDs. That README's original native-pending
statement is historical, not a claim that the later tests did not execute.
The official archive was not downloaded again for this diagnostic.

## Derived inputs, unchanged bytes

- Packed final routing geometry is the collector-verified public Apple fixture
  test attachment from source`b1f3a9ae2dca8b9a45ece285174253de5f172255`,
  run40780118332. Parsed geometry SHA256:
  `0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7`.
- The25 requested points and declared body profiles are fixed diagnostic
  scenarios, **not measured people, live body poses or personal movement history**.
  Request file SHA256:
  `e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51`.
- Strict control results are the actual public GitHub test artifact from source
  `ceaaa1c1fc685b043934c4be1ade75653227e1bf`, run40791907324, resultSHA256
  `0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893`.
- The new exclusion masks are deterministic derivatives of those same geometry
  inputs and the frozen six compact captures; mask file SHA256:
  `13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a`.
  Nothing was rewritten or substituted to make an upload or test pass.

This packet contains no user scan, photograph, video, RGB-D frame, person name,
face, family memory or device capture. The original opaque Apple`coreModel`
payload is not recopied into this packet; only its already verified exported
triangle geometry and original public metadata are used. Do not infer a broader
privacy audit of Apple's opaque historical model from this limited boundary.

The5,267,537-byte raw full compact capture is retained locally with SHA256
`71761f53b3567b6ac5e09d38c95f9a015249062c35ee84ae0cbade1a1f1977e1` and is
**excluded from the minimal CI publication packet**. Its source/recipe and bounded
receipts remain available. The native probe validates the entire compact layout
hash before applying a mask; it does not need to upload the large raw capture.

No MuSHRoom/other map payload, personal dataset or private capture is part of
this packet. Any such separate pending publication remains outside this scope.
The root publisher must independently verify the exact allowlist, public source
identity and repository visibility. This provenance record does not authorize
publishing any other file or overriding a specific permission denial.

## Reused implementation references

The distance transform is the existing installed SciPy1.17.0 release, pinned in
the sibling EDT diagnostic to commit`8c75ae75176236f233824e9a0483c26a69e6dfec`
with its BSD-3-Clause license. Recast/Detour remains the repository's existing
unmodified pinned upstream. The Mac scratch hook uses Apple's documented
[CommonCrypto SHA256 API](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/CC_SHA256_Final.3cc.html)
to bind full layout bytes; no custom hashing or new package install is introduced.
Neither a hash match nor a no-contact model test establishes physical clearance.
