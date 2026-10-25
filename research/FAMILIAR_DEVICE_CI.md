# Optional familiar backend unsigned device CI candidate

Separate path-filtered master-push/manual xcode-27 job compiles the existing YuNet/SFace native bridge for generic iOS device, with signing disabled. No simulator/native execution/accuracy claim. The framework lacks arm64 simulator support; no Intel runner is assumed. Existing default generated project remains byte-identical; a separate BlindAssistFamiliarBench.xcodeproj is generated on the runner only.

Downloads only official content-pinned artifacts: OpenCV4.14 framework75,208,871B, YuNet232,589B, SFace38,696,353B. Exact bytes and SHA256 are verified before use, including existing cached files. Missing or mismatched artifacts fail closed. Source paths are validated by existing verifyFamiliarInputs. Checked locally against all three actual downloaded assets and generated-source/resource references; Apple compilation is pending.

OpenCV core Apache2 notice and existing MIT YuNet/Apache2 SFace notices retained in private runner asset directory. Static binary build information lists libprotobuf, libjpeg-turbo, libwebp, libpng, zlib, ade and builtin flatbuffers; full transitive redistribution notice audit is still pending. No binary redistribution is performed: no upload-artifact, app/framework/model publication or packaged release. A successful compile does not authorize binary distribution before that audit.

No default build flags changed, paid services, signing account, secrets, personal photos, gallery enrollment or model threshold changes. The job's private runner scratch is outside repository. Publishing the workflow/helper or listed familiar-backend inputs on master triggers this bounded job. Other unrelated pushes do not. Public-only repository guard and40-minute timeout remain.
