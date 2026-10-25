# Native correction v2 — still staged, no application activation

This revision retains the original 71-check `source/` archive and its evidence unchanged. It changes only file-protection attribute verification in the iOS actor. The unchanged Foundation contract remains `../source/VoiceEnrollment.swift`.

Apple documents `FileAttributeKey.protectionKey` as an NSString-valued attribute: https://developer.apple.com/documentation/foundation/fileattributekey/protectionkey . `FileProtectionType` is a RawRepresentable structure: https://developer.apple.com/documentation/foundation/fileprotectiontype . The original actor directly cast the returned attribute to that structure. Native run 40205942187 executed both scenario tests and failed at that guard; those failures are preserved, not reclassified as passes.

`VoiceEnrollmentFileProtection.isComplete` accepts either an already-typed exact `.complete` or a bridged String whose `FileProtectionType(rawValue:)` is exactly `.complete`. It rejects missing, unknown, unsupported-type and weaker protection values. Backup exclusion must still independently equal true. Set/verify security calls, atomic writes, deletion protocol, default Application Support directory, save ownership, and all authority behavior remain unchanged. No simulator exemption or fallback is introduced.

A third native test checks typed, String, NSString, missing, weaker, unknown and numeric inputs. The two actor scenario assertions remain unchanged. Test-only projection diagnostics print only boolean verification results and attribute type for synthetic temp fixtures; they do not print paths or record data. Actual runtime evidence is still needed to distinguish original cast behavior from simulator protection capability.

Native-v2 SDK/typecheck and 3-test execution are pending rerun. Local evidence comprises four portable projection/guard tests and Swift syntax parsing, not native acceptance. Missing/weaker simulator protection remains a hard failure; physical-device storage/lock/backup, power-loss, single-owner lifecycle and UI deletion retry remain separate gates. No app target or capture path uses this source.
