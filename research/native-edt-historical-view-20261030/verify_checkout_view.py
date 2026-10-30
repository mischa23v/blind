#!/usr/bin/env python3
"""Reproduce source staging only from an existing checkout, never execute native code."""
import argparse,json,pathlib,tempfile
import run_snapshot as m
p=argparse.ArgumentParser();p.add_argument('--repo',type=pathlib.Path,required=True);args=p.parse_args()
m.verify_packet();b,pins=m.load_pins()
with tempfile.TemporaryDirectory(prefix='edt-source-only-') as t:
 view=pathlib.Path(t)/'view';m.stage_view(args.repo.resolve(),view,pins,b)
 original=(view/m.LANE/'run_native.py').read_bytes();text,_=m.transform_runner(original)
 print(json.dumps({'status':'historical-input-view-source-only-verified','all58HistoricalHashesMatch':True,'historicalInputCount':58,'historicalPinManifestSHA256':m.PIN_SHA,'generatedRunnerSHA256':m.digest(text.encode()),'nativeExecuted':False},sort_keys=True))
