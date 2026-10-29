"""Finite export-convention diagnostic, NOT documented calibration or accuracy.

Only the 24 proper signed permutations are fitted; raw world poses are fixed.
This source must not be executed until the parent reviews its frozen identity.
"""
import os
for key in ('OPENBLAS_NUM_THREADS', 'OMP_NUM_THREADS', 'MKL_NUM_THREADS', 'NUMEXPR_NUM_THREADS'):
    os.environ[key] = '1'
import argparse
import csv
import hashlib
import importlib.util
import itertools
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image

if not __debug__:
    raise RuntimeError('Assertions are required for fail-closed synthetic gates')

HERE = Path(__file__).resolve().parent
LEGACY = HERE.parent / 'scalemaster-scale-diagnostic' / 'diagnostic.py'
LEGACY_SHA = '9f774ff9d152f0485fc1fd762d8068ee9abe561cf1898f080f11989fb77432ee'
if hashlib.sha256(LEGACY.read_bytes()).hexdigest() != LEGACY_SHA:
    raise RuntimeError('Original estimator source changed; do not continue')
spec = importlib.util.spec_from_file_location('frozen_scale_diagnostic', LEGACY)
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

F = np.diag([1., -1., -1.])
CONVENTION_GAP = .01
JACKKNIFE_GAP = .005


def conventions():
    """Lexicographic enumeration, exact integer rotations, determinant +1 only."""
    out = []
    for permutation in itertools.permutations(range(3)):
        for signs in itertools.product((-1, 1), repeat=3):
            C = np.zeros((3, 3), dtype=int)
            C[np.arange(3), permutation] = signs
            if round(np.linalg.det(C)) == 1:
                assert np.array_equal(C.T @ C, np.eye(3))
                out.append(C)
    out.sort(key=lambda c: tuple(c.ravel()))
    assert len(out) == 24 and len({tuple(c.ravel()) for c in out}) == 24
    return [(f'C{i:02d}', C) for i, C in enumerate(out)]


def controls(pairs):
    return {
        'zero_translation': base.profile([dict(p, t=np.zeros(3)) for p in pairs], base.SCALES),
        'cyclic_pose_shuffle': base.profile([
            dict(p, R=pairs[(i + 1) % len(pairs)]['R'], t=pairs[(i + 1) % len(pairs)]['t'])
            for i, p in enumerate(pairs)], base.SCALES),
    }


def convention_search(pair_builder):
    """Development-only fit. Every convention receives the original scale search."""
    results = []
    for name, C in conventions():
        fit = base.fit(pair_builder(C))
        results.append({'id': name, 'optical_to_recorded_camera': C.tolist(), 'development': fit})
    ranked = sorted((r for r in results if r['development']['best'] is not None),
                    key=lambda r: (r['development']['best']['score'], r['id']))
    if not ranked:
        return {'conventions': results, 'candidate': None, 'reasons': ['all_conventions_ineligible'], 'jackknife': []}
    winner = ranked[0]
    best = winner['development']['best']
    reasons = []
    if winner['development']['status'] != 'conditional_candidate_only':
        reasons.append(winner['development']['status'])
    if best['score'] > .15:
        reasons.append('development_residual_too_large')
    margin = ranked[1]['development']['best']['score'] - best['score'] if len(ranked) > 1 else None
    if margin is not None and margin < CONVENTION_GAP:
        reasons.append('convention_not_unique_at_preregistered_margin')
    # Stability uses the SAME shared 25-point coarse grid for all conventions.
    # Four leave-one-development-pair-out projections of existing scores only;
    # no new optimization, pair replacement, or holdout data is involved.
    stability = []
    for omitted in range(4):
        choices = []
        for r in results:
            for row in r['development']['profile'][:len(base.SCALES)]:
                metrics = [v for i, v in enumerate(row['pairs']) if i != omitted]
                if all(v['eligible'] for v in metrics):
                    choices.append((float(np.mean([v['score'] for v in metrics])), r['id'], row['scale_m_per_unit']))
        by_convention = {}
        for score, name, scale in sorted(choices):
            by_convention.setdefault(name, (score, scale))
        ranking = sorted((score, name, scale) for name, (score, scale) in by_convention.items())
        if not ranking:
            stability.append({'omitted_development_pair': omitted, 'status': 'ineligible'})
            reasons.append('development_jackknife_ineligible')
            continue
        score, name, scale = ranking[0]
        gap = ranking[1][0] - score if len(ranking) > 1 else None
        scale_factor = max(scale / best['scale_m_per_unit'], best['scale_m_per_unit'] / scale)
        ok = name == winner['id'] and (gap is None or gap >= JACKKNIFE_GAP) and scale_factor <= 4
        stability.append({'omitted_development_pair': omitted, 'winner_id': name, 'score': score,
                          'scale_m_per_unit': scale, 'runner_up_gap': gap,
                          'scale_factor_from_full_development': scale_factor, 'stable': ok})
        if not ok:
            reasons.append('convention_or_scale_not_stable_under_development_jackknife')
    return {'conventions': results, 'candidate': {'id': winner['id'],
            'optical_to_recorded_camera': winner['optical_to_recorded_camera'],
            'scale_m_per_unit': best['scale_m_per_unit'], 'score': best['score'],
            'runner_up_convention_score_gap': margin}, 'reasons': sorted(set(reasons)), 'jackknife': stability}


def control_reasons(ctrl, score):
    reasons = []
    zero = [r['score'] for r in ctrl['zero_translation'] if r['score'] is not None]
    shuffled = [r['score'] for r in ctrl['cyclic_pose_shuffle'] if r['score'] is not None]
    if not zero or max(zero) - min(zero) > 1e-3:
        reasons.append('zero_translation_control_uninformative_or_nonflat')
    if zero and min(zero) < score + .01:
        reasons.append('zero_translation_fits_equally_well_or_better')
    if shuffled and min(shuffled) < score + .01:
        reasons.append('shuffled_poses_not_worse_enough')
    return reasons


def refined_controls(pairs):
    """Additional conservative check; original coarse control gates remain intact."""
    zero = [dict(p, t=np.zeros(3)) for p in pairs]
    shuffled = [dict(p, R=pairs[(i+1) % len(pairs)]['R'], t=pairs[(i+1) % len(pairs)]['t'])
                for i, p in enumerate(pairs)]
    return {'zero_translation': base.fit(zero), 'cyclic_pose_shuffle': base.fit(shuffled)}


def refined_control_reasons(ctrl, score):
    reasons = []
    for name, result in ctrl.items():
        if result['best'] is not None and result['best']['score'] < score + .01:
            reasons.append(name + '_equally_refined_control_not_worse_enough')
    return reasons


def assert_equivalent(actual, expected, path='root'):
    """Roundoff-only tolerance, never different eligibility/status/profile structure."""
    if isinstance(expected, dict):
        if set(actual) != set(expected):
            raise AssertionError(f'Original-F regression keys differ: {path}')
        for key in expected:
            assert_equivalent(actual[key], expected[key], path + '.' + key)
    elif isinstance(expected, list):
        if len(actual) != len(expected):
            raise AssertionError(f'Original-F regression length differs: {path}')
        for i, (a, b) in enumerate(zip(actual, expected)):
            assert_equivalent(a, b, f'{path}[{i}]')
    elif isinstance(expected, (int, float)) and not isinstance(expected, bool):
        if not isinstance(actual, (int, float)) or not math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12):
            raise AssertionError(f'Original-F regression numeric mismatch: {path}')
    elif actual != expected:
        raise AssertionError(f'Original-F regression value mismatch: {path}')


def load_images(specs, run, receipt):
    data, audit = {}, {}
    for i in sorted({p[k] for p in specs for k in ('i', 'j')}):
        arrays = []
        for kind in ('depth', 'confidence'):
            path = run / 'images' / f'{kind}_{i:06d}.png'
            if hashlib.sha256(path.read_bytes()).hexdigest() != receipt['files'][path.name]:
                raise RuntimeError('Saved PNG changed')
            with Image.open(path) as im:
                array = np.asarray(im).copy()
            if array.shape != (192, 256):
                raise RuntimeError('Image shape changed')
            if kind == 'depth' and array.dtype != np.uint16:
                raise RuntimeError('Depth dtype changed')
            if kind == 'confidence' and (array.dtype != np.uint8 or not set(np.unique(array)) <= {0, 1, 2}):
                raise RuntimeError('Confidence codes changed')
            arrays.append(array)
        data[i] = arrays
        d, c = arrays
        audit[str(i)] = {'zero_count': int((d == 0).sum()), 'code_65535_count': int((d == 65535).sum()),
                        'saturated_dtype_max_count': int((d == np.iinfo(d.dtype).max).sum()),
                        'confidence_counts': {str(k): int((c == k).sum()) for k in (0, 1, 2)},
                        'numeric_mask_kept': int(((d > 0) & (d < 65535) & (c == 2)).sum()),
                        'reason': '0/65535 conservatively excluded, semantics unknown; no metric cutoff'}
    return data, audit


def pairs_for(specs, data, poses, K, C):
    pairs = []
    for p in specs:
        i, j = p['i'], p['j']
        Ri, ti = poses[i]; Rj, tj = poses[j]
        Ri = Ri @ C; Rj = Rj @ C
        pairs.append(base.make_pair(data[i][0], data[j][0], data[i][1], data[j][1], K,
                                    Rj.T @ Ri, Rj.T @ (ti - tj)))
    return pairs


def real_run(run, out):
    m = json.loads((run / 'frozen-pairs.json').read_text())
    receipt = json.loads((run / 'images/receipt.json').read_text())
    prior = json.loads((run / 'diagnostic-result.json').read_text())
    manifest_sha = hashlib.sha256((run / 'frozen-pairs.json').read_bytes()).hexdigest()
    if receipt['manifest_sha256'] != manifest_sha:
        raise RuntimeError('Extraction manifest mismatch')
    for key in ('pose', 'camera_matrix'):
        if hashlib.sha256(Path(m[key + '_path']).read_bytes()).hexdigest() != m[key + '_sha256']:
            raise RuntimeError('Frozen metadata changed')
    with open(m['camera_matrix_path']) as f:
        Kraw = [[float(v.strip()) for v in row] for row in csv.reader(f)]
    K = np.array([[v * (256/1920) for v in Kraw[0]], [v * (192/1440) for v in Kraw[1]], Kraw[2]])
    if not np.array_equal(K, np.asarray(m['geometry_assumptions']['K'])):
        raise RuntimeError('Exact pinned K derivation differs')
    poses = base.pose_map(m['pose_path'], np.eye(3))
    devspec = [p for p in m['pairs'] if p['split'] == 'development']
    holdspec = [p for p in m['pairs'] if p['split'] == 'holdout']
    if len(devspec) != 4 or len(holdspec) != 2:
        raise RuntimeError('Frozen split changed')
    data, audit = load_images(devspec, run, receipt)
    build = lambda C: pairs_for(devspec, data, poses, K, C)
    # Must reproduce run-001 BEFORE searching alternatives; stop on any mismatch.
    baseline_pairs = build(F)
    baseline_fit = base.fit(baseline_pairs)
    baseline_controls = controls(baseline_pairs)
    assert_equivalent(baseline_fit, prior['development'])
    assert_equivalent(baseline_controls, prior['controls'])
    if baseline_fit['status'] != 'inconclusive_no_coverage' or baseline_fit['best'] is not None:
        raise RuntimeError('Original F did not reproduce the prior inconclusive result')
    search = convention_search(build)
    candidate = search['candidate']
    reasons = list(search['reasons'])
    ctrl, fair_ctrl, held = None, None, None
    holdout_state = 'not_evaluated_no_development_candidate'
    # Controls are reported for the numerical best even when convention gates fail.
    if candidate:
        C = np.asarray(candidate['optical_to_recorded_camera'])
        winner_pairs = build(C)
        ctrl = controls(winner_pairs)
        fair_ctrl = refined_controls(winner_pairs)
        reasons += control_reasons(ctrl, candidate['score'])
        reasons += refined_control_reasons(fair_ctrl, candidate['score'])
        holdout_state = 'not_evaluated_development_or_control_gates_failed'
        if not reasons:
            # Durable dev-only lock precedes decoding or scoring either holdout.
            lock = {'candidate': candidate, 'manifest_sha256': manifest_sha,
                    'selection_scope': 'four development pairs only; no holdout pixels loaded',
                    'development_gate_reasons': [], 'refit_permitted': False}
            with (out / 'development-candidate-lock.json').open('x') as f:
                json.dump(lock, f, indent=2)
            hdata, haudit = load_images(holdspec, run, receipt)
            audit.update(haudit)
            held = base.profile(pairs_for(holdspec, hdata, poses, K, C), [candidate['scale_m_per_unit']])[0]
            holdout_state = 'evaluated_once_at_locked_development_candidate'
            if held['score'] is None:
                reasons.append('heldout_ineligible_coverage')
            else:
                for p in held['pairs']:
                    if p['score'] > .15 or p['score'] > candidate['score'] + .03:
                        reasons.append('heldout_residual_not_consistent_with_development')
                    if any(p[d]['median_visible_log_residual'] is None or p[d]['median_visible_log_residual'] > .10
                           for d in ('forward', 'reverse')):
                        reasons.append('heldout_visible_residual_too_large')
    return {'interpretation': 'Inferred export-convention/scale consistency only; not verified units, independent calibration, or metric accuracy',
            'original_run_preserved': True, 'manifest_sha256': manifest_sha,
            'original_F_regression': {'status': 'passed', 'development': baseline_fit, 'controls': baseline_controls},
            'family_search_development_only': search, 'best_candidate_controls': ctrl,
            'additional_equally_refined_controls': fair_ctrl,
            'heldout_state': holdout_state, 'heldout_at_locked_development_candidate_only': held,
            'mask_audit_for_decoded_images': audit, 'quaternion_normalization': m['quaternion_normalization'],
            'geometry_assumptions': m['geometry_assumptions'], 'RGB_sync': 'UNRESOLVED; RGB not used',
            'diagnostic_decision': {'status': 'inconclusive' if reasons else 'candidate_survives_preregistered_internal_checks',
                                    'reasons': sorted(set(reasons))},
            'no_direction_inversion_no_pose_fit_no_pair_reselection': True}


def axis_rotation(axis, angle):
    axis = np.asarray(axis, dtype=float); axis /= np.linalg.norm(axis)
    x, y, z = axis
    cross = np.array([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
    return np.eye(3) + math.sin(angle) * cross + (1 - math.cos(angle)) * (cross @ cross)


def render_scene(K, shape, R, t):
    """Analytic asymmetric static scene: slanted background and three spheres."""
    v, u = np.indices(shape)
    rays = np.stack(((u-K[0,2])/K[0,0], (v-K[1,2])/K[1,1], np.ones(shape)), axis=-1) @ R.T
    normal = np.array([.17, -.11, 1.])
    # Five-metre background keeps the deliberate zero-translation control's
    # background visible under the unchanged 5% occlusion rule for these motions.
    depth = (5.0 - normal @ t) / (rays @ normal)
    for center, radius in [((-.65, -.35, 2.0), .40), ((.62, .38, 2.35), .54), ((.20, -.55, 2.8), .29)]:
        delta = t - np.asarray(center)
        aa = (rays * rays).sum(axis=-1); bb = 2 * (rays @ delta)
        discriminant = bb * bb - 4 * aa * (delta @ delta - radius * radius)
        hit = (-bb - np.sqrt(np.maximum(discriminant, 0))) / (2 * aa)
        depth = np.where((discriminant >= 0) & (hit > 0) & (hit < depth), hit, depth)
    assert np.isfinite(depth).all() and (depth > 0).all()
    return depth


def synthetic_checks():
    legacy_checks = base.synthetic_checks()
    K = np.array([[60., 0, 31.5], [0, 60., 23.5], [0, 0, 1.]])
    shape = (48, 64); confidence = np.full(shape, 2, np.uint8); true_scale = .001
    Ctrue = np.array([[0, -1, 0], [0, 0, -1], [1, 0, 0]])
    translations = ((.14, .02, .18), (-.04, .13, .15), (.11, -.12, .20), (-.12, -.07, .16))
    axes = ((1, 2, 3), (2, -1, 1), (-1, 3, 2), (3, 1, -2))
    synthetic = []
    di = render_scene(K, shape, np.eye(3), np.zeros(3)) / true_scale
    for n, (t, axis) in enumerate(zip(translations, axes)):
        Rj = axis_rotation(axis, math.radians((3, -4, 5, -3)[n])); tj = np.array(t)
        dj = render_scene(K, shape, Rj, tj) / true_scale
        synthetic.append((di, dj, np.eye(3) @ Ctrue.T, Rj @ Ctrue.T, tj))
    def build(C):
        out = []
        for a, b, raw_i, raw_j, tj in synthetic:
            Ri, Rj = raw_i @ C, raw_j @ C
            out.append(base.make_pair(a, b, confidence, confidence, K, Rj.T @ Ri, -Rj.T @ tj))
        return out
    recovered = convention_search(build)
    candidate = recovered['candidate']
    assert candidate and np.array_equal(np.asarray(candidate['optical_to_recorded_camera']), Ctrue), 'Known axis mismatch was not recovered'
    assert abs(math.log(candidate['scale_m_per_unit'] / true_scale)) < .15, 'Known scale not recovered'
    assert not recovered['reasons'], ('Known asymmetric convention did not pass uniqueness/stability gates', recovered['reasons'])
    wrong = base.fit(build(F))
    assert wrong['best'] is None or wrong['best']['score'] >= candidate['score'] + CONVENTION_GAP, 'Wrong-axis control not worse'
    ctrl = controls(build(Ctrue))
    assert not control_reasons(ctrl, candidate['score']), 'Known-case controls failed'
    fair_ctrl = refined_controls(build(Ctrue))
    assert not refined_control_reasons(fair_ctrl, candidate['score']), 'Known-case equally refined controls failed'
    # Zero motion makes ALL 24 conventions equivalent; never certify one by tie order.
    static = base.make_pair(di, di, confidence, confidence, K, np.eye(3), np.zeros(3))
    ambiguity = convention_search(lambda C: [static] * 4)
    assert ambiguity['reasons'] and 'convention_not_unique_at_preregistered_margin' in ambiguity['reasons']
    # Pure forward translation viewing a featureless plane has a four-way roll ambiguity.
    plane = np.full(shape, 2. / true_scale)
    def roll_ambiguous(C):
        return [base.make_pair(plane, np.full(shape, (2-dz)/true_scale), confidence, confidence, K,
                               np.eye(3), C.T @ np.array([0., 0., -dz])) for dz in (.12, .16, .20, .24)]
    roll = convention_search(roll_ambiguous)
    assert 'convention_not_unique_at_preregistered_margin' in roll['reasons'], 'Roll ambiguity was falsely resolved'
    return {'legacy_implementation_checks': legacy_checks, 'known_axis_and_scale_recovery': recovered,
            'wrong_original_F_control': wrong, 'known_case_controls': ctrl,
            'known_case_equally_refined_controls': fair_ctrl,
            'zero_motion_ambiguity': ambiguity, 'forward_plane_roll_ambiguity': roll,
            'meaning': 'Synthetic implementation validation only, no real dataset calibration evidence'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--synthetic-only', action='store_true')
    parser.add_argument('--approve-real-run', action='store_true')
    parser.add_argument('--previous-run'); parser.add_argument('--output-root', required=True)
    args = parser.parse_args(); out = Path(args.output_root)
    if args.synthetic_only:
        result = synthetic_checks(); target = out / 'synthetic-checks.json'
    else:
        if not args.approve_real_run or not args.previous_run:
            raise SystemExit('Reviewed bounded runner required')
        result = real_run(Path(args.previous_run), out); target = out / 'diagnostic-result.json'
    with target.open('x') as f:
        json.dump(result, f, indent=2)
    print(target)


if __name__ == '__main__':
    main()
