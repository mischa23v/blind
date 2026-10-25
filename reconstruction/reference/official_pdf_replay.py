#!/usr/bin/env python3
"""Bounded local-only replay adapter, NOT an iOS PDF/recognition integration.

The public PDF must be downloaded separately. Raw PDF, extracted text, generated
fixture and simulated speech output stay in a private directory OUTSIDE the
source repository. Only hashes, metadata and boolean/count evidence are exported.
Uses installed pdftotext and Python stdlib; no model, OCR replacement or installs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import uuid

URL = "https://media3.bosch-home.com/Documents/9001427628_A.pdf"
PDF_SHA256 = "dcbd212e6c8f564d3ef02e97b0d261ee547f32e751a46679ed2f0db27fc71d3c"
SECTION_SHA256 = "570812f1bfd111f9a32c275eae49af3332ee51f81a8482e2571f47db0eefecd9"
MODEL = "WAT28400UC"
LEGAL_URL = "https://www.bosch-home.com/us/en/c/legal/blt068e61b5256d1dc7"


def digest(value):
    return hashlib.sha256(value).hexdigest()


def expected_public_metadata(input_fixture_sha256):
    # Pinned, reviewed public metadata. Never copy arbitrary private JSON keys or
    # strings into a publishable report, even if that private file says redacted.
    return {"url": URL, "source_kind": "official manufacturer PDF", "model_as_printed": MODEL,
            "variant_suffix": "not independently bound; no physical appliance identity claim",
            "pdf_sha256": PDF_SHA256, "pdf_bytes": 4943563, "pdf_page_one_based": 29,
            "extraction": "pdftotext version 25.03.0 -raw",
            "page_text_sha256": "253a7c32a2400bd1201f96541ab41985bc08be76a60c5ebf6944efb6a6cb0820",
            "section_sha256": SECTION_SHA256, "section_utf8_bytes": 699, "section_whitespace_words": 123,
            "heading_only_section_sha256": "3db8a23160f6fbc3caab4166b623f91a4f6d17c3919e42672c941984ac24e1c8",
            "license": "Copyrighted manufacturer document. No open redistribution license found; no raw PDF or long quotations published.",
            "license_source_url": LEGAL_URL,
            "visual_review": "Pinned PDF page 29 was visually reviewed on 2026-10-25 for column order and complete-section extraction; this command does not itself perform visual review.",
            "scope": "Text-layer extraction, not OCR or a native/manual recognition adapter. No LLM.",
            "input_fixture_sha256": input_fixture_sha256}


def read_page(pdf, page):
    return subprocess.run(["pdftotext", "-f", str(page), "-l", str(page), "-raw", str(pdf), "-"],
                          check=True, capture_output=True, timeout=20).stdout.decode("utf-8")


def section(page, heading, next_heading):
    start_marker, end_marker = "\n" + heading + "\n", "\n" + next_heading + "\n"
    if page.count(start_marker) != 1 or page.count(end_marker) != 1:
        raise ValueError("Source section markers changed; do not guess or truncate.")
    start = page.index(start_marker) + 1
    end = page.index(end_marker, start) + 1
    if end <= start:
        raise ValueError("Source reading order changed.")
    text = page[start:end]
    body_offset = len((heading + "\n").encode("utf-16-le")) // 2
    return {"id": str(uuid.uuid5(uuid.NAMESPACE_URL, URL + "#page29:" + heading)),
            "text": text, "bodyOffsetUTF16": body_offset,
            "bodyLengthUTF16": len(text.encode("utf-16-le")) // 2 - body_offset,
            "locator": MODEL + ", PDF page 29, section " + heading}


def extract(args):
    pdf = Path(args.pdf).resolve()
    private = Path(args.private_output).resolve()
    publish_root = Path(__file__).resolve().parents[2]
    if private == publish_root or publish_root in private.parents or publish_root in pdf.parents:
        raise ValueError("Raw PDF/reference output cannot be inside the source staging tree.")
    with pdf.open("rb") as stream:
        data = stream.read(12 * 1024 * 1024 + 1)
    if len(data) > 12 * 1024 * 1024 or digest(data) != PDF_SHA256 or not data.startswith(b"%PDF-"):
        raise ValueError("PDF bytes do not match the pinned official source.")
    cover = read_page(pdf, 1)
    if not re.search(r"(?m)^\s*" + re.escape(MODEL) + r"\s*$", cover):
        raise ValueError("The exact printed model is absent from the cover.")
    page = read_page(pdf, 29)
    positive = section(page, "Finish in", "Additional Program Option settings")
    negative = section(page, "Changing the temperature range", "Changing the spin speed range")
    if digest(positive["text"].encode()) != SECTION_SHA256:
        raise ValueError("Extracted source block changed; review rather than silently rebaseline.")
    private.mkdir(parents=True, exist_ok=True)
    (private / "official-page29-raw.txt").write_text(page)
    identity = {"sourceID": str(uuid.uuid5(uuid.NAMESPACE_URL, URL)),
                "revision": str(uuid.uuid5(uuid.NAMESPACE_URL, URL + "#" + PDF_SHA256)),
                "sha256": PDF_SHA256, "exactModel": MODEL}
    fixture = {"provenance": "Official manufacturer PDF text extraction; simulated Core playback, no device observation.",
               "url": URL, "identity": identity, "positive": positive, "negative": negative,
               "query": "Finish in", "headingOnlyQuery": "Changing the temperature range"}
    (private / "official-reference-input.json").write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n")
    version = subprocess.run(["pdftotext", "-v"], capture_output=True, text=True, check=True).stderr.splitlines()[0]
    result = expected_public_metadata(digest((private / "official-reference-input.json").read_bytes()))
    if (version + " -raw" != result["extraction"] or len(data) != result["pdf_bytes"]
            or digest(page.encode()) != result["page_text_sha256"]
            or digest(negative["text"].encode()) != result["heading_only_section_sha256"]):
        raise ValueError("Pinned extraction tool or page data changed; review before publishing.")
    (private / "extraction-redacted.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


def redact(args):
    private = Path(args.private_output).resolve()
    fixture = json.loads((private / "official-reference-input.json").read_text())
    output = json.loads((private / "official-reference-output.json").read_text())
    text = fixture["positive"]["text"]
    expected_locator = MODEL + ", PDF page 29, section Finish in"
    if digest(text.encode()) != SECTION_SHA256 or fixture["positive"]["locator"] != expected_locator:
        raise ValueError("Private source/locator no longer matches the pinned extraction.")
    if output.get("completed") is not True or not isinstance(output.get("chunks"), list):
        raise ValueError("A completed typed replay is required.")
    numeric_fields = ["completedChunkCount", "toolResultEncodedBytes", "modelResultBudgetBytes"]
    if any(type(output.get(key)) is not int or output[key] < 0 for key in numeric_fields):
        raise ValueError("Unexpected nonnumeric result metadata; nothing published.")
    if output.get("issuedAt") != 100 or output.get("deadline") != 160:
        raise ValueError("Original synthetic deadline was changed.")
    if output["completedChunkCount"] != len(output["chunks"]):
        raise ValueError("Replay did not complete every chunk.")
    for index, chunk in enumerate(output["chunks"]):
        if (chunk.get("locator") != expected_locator or type(chunk.get("index")) is not int
                or chunk["index"] != index or type(chunk.get("words")) is not int
                or not 1 <= chunk["words"] <= 35 or not isinstance(chunk.get("originalSlice"), str)
                or chunk.get("spokenText") != "The selected source says: «" + chunk["originalSlice"] + "»"):
            raise ValueError("Unexpected chunk shape/locator/attribution; nothing published.")
    recovered = "".join(chunk["originalSlice"] for chunk in output["chunks"])
    if recovered.encode() != text.encode():
        raise ValueError("Core output did not preserve/complete the original source block.")
    if any(chunk["words"] > 35 for chunk in output["chunks"]):
        raise ValueError("An attributed chunk exceeded the word cap.")
    private_metadata = json.loads((private / "extraction-redacted.json").read_text())
    result = expected_public_metadata(digest((private / "official-reference-input.json").read_bytes()))
    if (private_metadata.keys() != result.keys()
            or any(type(private_metadata[key]) is not type(result[key]) or private_metadata[key] != result[key]
                   for key in result)):
        raise ValueError("Unknown or changed extraction metadata; nothing published.")
    result.update({"actual_pipeline": ["pinned PDF SHA-256 check", "pdftotext -raw page extraction",
                     "exact cover model check", "complete section/body range extraction",
                     "CompanionToolResult + CompanionEvidence", "CompanionReferenceReading.prepare",
                     "SpeechDeliveryLedger.begin/finish with simulated outcomes", "byte-for-byte ordered reconstruction"],
                   "playback": "Synthetic callback outcomes and monotonic time. No audio device, AVSpeechSynthesizer or VoiceOver run.",
                   "core_chunk_count": len(output["chunks"]), "core_delivered_chunk_count": output["completedChunkCount"],
                   "tool_result_encoded_bytes": output["toolResultEncodedBytes"],
                   "model_result_budget_bytes": output["modelResultBudgetBytes"],
                   "source_bytes_preserved": True, "completed": output["completed"],
                   "issued_at_synthetic_monotonic": output["issuedAt"], "deadline_synthetic_monotonic": output["deadline"],
                   "chunk_trace": [{"index": c["index"], "words_including_attribution": c["words"],
                                     "original_slice_bytes": len(c["originalSlice"].encode()),
                                     "original_slice_sha256": digest(c["originalSlice"].encode()),
                                     "spoken_text_sha256": digest(c["spokenText"].encode()),
                                     "locator": expected_locator} for c in output["chunks"]]})
    Path(args.evidence_output).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"chunk_count": len(output["chunks"]), "source_bytes_preserved": True,
                      "tool_result_encoded_bytes": output["toolResultEncodedBytes"],
                      "evidence_output": args.evidence_output}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["extract", "redact"])
    parser.add_argument("--pdf")
    parser.add_argument("--private-output", required=True)
    parser.add_argument("--evidence-output")
    args = parser.parse_args()
    if args.action == "extract":
        if not args.pdf: parser.error("extract requires --pdf")
        extract(args)
    else:
        if not args.evidence_output: parser.error("redact requires --evidence-output")
        redact(args)
