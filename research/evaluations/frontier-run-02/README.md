# Preserved exploratory text evaluation

Unzip `frontier-full-conversations-bundle.zip` to read and verify the following original report. SHA256: `ed5991765e6cd6ddd236e88514a366b8125d1aeee260f5ab34075d993cd06db0`. This archive is historical evaluation evidence, not a current-source regression pass or the requested400 complete scenarios.

# Completed frontier plus code conversation report

Start with frontier-full-conversations.md. It contains all 23 authored inputs, every accepted reply, all four rejected candidates clearly marked NOT DELIVERED, and the full 79-call evidence ledger.

frontier-full-conversations.json is the machine-readable companion with exact original call records and structured per-turn deliveries. frontier-eval-02-frozen.jsonl is the unchanged original run. Original receipts, audits, source/input manifests, public evaluator instructions and run 01 transport evidence are preserved alongside it.

Run `python3 verify_report.py` and `sha256sum -c report-files.sha256` in this directory to check integrity. This report is based on completed run 02, not a new model evaluation. The original result remains 14 PASS / 1 FAIL, with the temporal resume interpretation explained in the report.

These are authored text simulations using real Swift core modules plus harness adapters, not native iPhone/audio/perception tests. Model identity/version is unverified. No real child's recordings, private chat, raw external datasets, embeddings, model files or secrets are included.
