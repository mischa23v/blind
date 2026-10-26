"""Source-only runtime factory for the existing three declared phone-map profiles.

No route selection, geometry correction, reference input or physical authority.
The original CandidateMap and profile-feasibility sources remain frozen.
"""
from pathlib import Path
import hashlib,json,sys
HERE=Path(__file__).resolve().parent;GAME=HERE.parent
sys.path.insert(0,str(GAME/'body-margin-variants-07'))
import margin_variants as variants


def open_profile_map(name,native_directory,native_library_sha256,proposal_radius=None):
    """Same isolated map/rectangle/native construction used by evaluate_variant."""
    cm=variants.base_module();g=variants.geometry(name,proposal_radius)
    directory=Path(native_directory).resolve()
    if variants.sha(directory/'libblind_detour.so')!=native_library_sha256:
        raise ValueError('approved native library identity required')
    rr=variants.rectangle_module(name,proposal_radius)
    de=variants.load_pinned('lap_detour_binding_'+name,directory/'detour_engine.py',variants.BINDING_SHA)
    model=cm.CandidateMap()
    try:
        model.close();model.rr=rr;model.de=de
        model.revision=hashlib.sha256((model.revision+json.dumps(g,sort_keys=True)+native_library_sha256).encode()).hexdigest()
        vertices,triangles=rr.quads(model.mask,model.origin,.05)
        vertices[:,2]*=-1;triangles=triangles[:,[0,2,1]].copy()
        model.engine=de.Engine(vertices,triangles,de.Config(radius=g['nativeRadiusIntended'],height=1.75,
            cell_size=variants.NATIVE_CELL_SIZE,max_climb=0.),mode='known-provided-map')
        return model
    except BaseException:
        model.close();raise
