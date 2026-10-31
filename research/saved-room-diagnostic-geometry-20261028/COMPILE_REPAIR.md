# Native directory-resource compiler repair

Run 40661837550 at ac56c97 failed both app build modes at PlaceStore.swift:88: the initializer URL parameter is immutable, but URL.setResourceValues is mutating. A local mutable URL copy now applies the same excluded-from-backup resource value to the same directory. Stored path, protection class, permissions and existing destination are unchanged. No privacy restriction is removed. Hosted/UI tests did not execute on the failed revision; this correction requires subsequent native validation.
