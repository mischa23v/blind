"""Exact union of existing VTK broad-phase bins, for ground setup only.

No triangle/ray predicate, geometry simplification or per-tick contact ordering
changes. The old ground adapter already sorted/uniqued the single-query IDs.
VTK 9.3.1 FindCellsWithinBounds visits the Cartesian product of endpoint bin
indices (including clamped out-of-bounds indices). Closed contiguous tiles
therefore visit the same bin union; overlapping visits are deduplicated here.
"""
import itertools
import math
import time
import numpy as np
import vtk

VTK_SOURCE = 'https://raw.githubusercontent.com/Kitware/VTK/v9.3.1/Common/DataModel/vtkStaticCellLocator.cxx'
MAX_TILES = 10_000
MAX_RAW_IDS = 32_000_000
MAX_TILE_SIZE = .25


class TiledBoundsUnavailable(RuntimeError):
    def __init__(self, message, **details):
        super().__init__(message)
        self.details = details


def _integer(value, name, minimum, maximum=None):
    if isinstance(value, bool) or not isinstance(value, (int, np.integer)):
        raise ValueError(name+' must be an integer')
    value = int(value)
    if value < minimum or (maximum is not None and value > maximum):
        raise ValueError(name+' is outside its declared resource bound')
    return value


def tile_edges(bounds, tile_size=.25, max_tiles=MAX_TILES):
    """Shared closed endpoints; original outer endpoints remain exact."""
    b = np.asarray(bounds, dtype=np.float64)
    if b.shape != (6,) or not np.isfinite(b).all():
        raise ValueError('finite six-value reference AABB required')
    if np.any(b[1::2] < b[::2]):
        raise ValueError('inverted reference AABB')
    if isinstance(tile_size, bool) or not math.isfinite(float(tile_size)) or not 0 < float(tile_size) <= MAX_TILE_SIZE:
        raise ValueError('tile size must be positive and no greater than .25 reference units')
    tile_size = float(tile_size)
    max_tiles = _integer(max_tiles, 'max_tiles', 1, MAX_TILES)
    spans = b[1::2]-b[::2]
    if not np.isfinite(spans).all():
        raise ValueError('reference AABB extent overflow')
    counts = []
    for span in spans:
        ratio = float(span)/tile_size
        if not math.isfinite(ratio) or ratio > max_tiles:
            raise TiledBoundsUnavailable('tile-count resource cap', maxTiles=max_tiles)
        counts.append(max(1, math.ceil(ratio)))
    if math.prod(counts) > max_tiles:
        raise TiledBoundsUnavailable('tile-count resource cap', requestedTiles=math.prod(counts), maxTiles=max_tiles)
    edges = tuple(np.linspace(b[2*a], b[2*a+1], counts[a]+1, dtype=np.float64) for a in range(3))
    for a, e in enumerate(edges):
        if e[0] != b[2*a] or e[-1] != b[2*a+1] or np.any(e[1:] < e[:-1]):
            raise TiledBoundsUnavailable('non-contiguous floating-point partition')
        # Roundoff cannot silently create a physically larger query tile.
        if np.any(np.diff(e) > tile_size+8*np.finfo(np.float64).eps*max(1., abs(b[2*a]), abs(b[2*a+1]))):
            raise TiledBoundsUnavailable('tile-width roundoff exceeds guard')
        e.setflags(write=False)
    return edges


def find_cells_tiled(locator, bounds, *, check, unique_cap, tile_size=.25,
                     max_tiles=MAX_TILES, max_raw_ids=MAX_RAW_IDS):
    """Return (sorted readonly original cell IDs, bounded-query receipt).

    ``check`` is the existing scorer/surface owner/error check. It is called
    before and after every VTK query. The dataset and locator MTimes are also
    bound locally. A cap failure is setup unavailable, never an empty free set.
    The built locator and dataset must remain single-owner immutable.
    """
    if not callable(check): raise ValueError('existing owner/error checker required')
    if vtk.vtkVersion.GetVTKVersion() != '9.3.1' or not locator.IsA('vtkStaticCellLocator'):
        raise ValueError('existing upstream VTK 9.3.1 vtkStaticCellLocator required')
    unique_cap = _integer(unique_cap, 'unique_cap', 0)
    max_raw_ids = _integer(max_raw_ids, 'max_raw_ids', 0, MAX_RAW_IDS)
    edges = tile_edges(bounds, tile_size, max_tiles)
    check()
    mesh = locator.GetDataSet()
    if mesh is None or mesh.GetNumberOfCells() < 1:
        raise TiledBoundsUnavailable('built nonempty reference dataset required')
    mesh_revision = mesh.GetMTime(); locator_revision = locator.GetMTime()
    cell_count = mesh.GetNumberOfCells()
    def owner_check():
        check()
        if (locator.GetDataSet() != mesh or mesh.GetMTime() != mesh_revision
                or locator.GetMTime() != locator_revision or mesh.GetNumberOfCells() != cell_count):
            raise TiledBoundsUnavailable('reference locator/dataset owner or revision changed')
    owner_check(); started = time.monotonic(); chunks = []; raw_count = 0; query_count = 0; largest = 0
    for ix, iy, iz in itertools.product(*(range(len(e)-1) for e in edges)):
        tile = [edges[0][ix], edges[0][ix+1], edges[1][iy], edges[1][iy+1], edges[2][iz], edges[2][iz+1]]
        found = vtk.vtkIdList(); owner_check()
        try: locator.FindCellsWithinBounds(tile, found)
        finally: owner_check()
        query_count += 1; n = found.GetNumberOfIds(); raw_count += n; largest = max(largest, n)
        if raw_count > max_raw_ids:
            raise TiledBoundsUnavailable('raw-ID resource cap', rawIDs=raw_count, maxRawIDs=max_raw_ids, completedTiles=query_count)
        if n:
            ids = np.fromiter((found.GetId(i) for i in range(n)), dtype=np.int64, count=n)
            if np.any(ids < 0) or np.any(ids >= cell_count):
                raise TiledBoundsUnavailable('native query returned invalid original cell ID')
            chunks.append(ids)
    original = np.unique(np.concatenate(chunks)) if chunks else np.empty(0, dtype=np.int64)
    owner_check()
    if len(original) > unique_cap:
        raise TiledBoundsUnavailable('unique-ID resource cap', uniqueIDs=len(original), uniqueCap=unique_cap, rawIDs=raw_count, completedTiles=query_count)
    original.setflags(write=False)
    return original, {'kind': 'same VTK broad-phase bin union via closed contiguous AABB tiles',
        'VTKVersion': '9.3.1', 'VTKSource': VTK_SOURCE, 'sourceLines': [486, 530],
        'referenceBounds': np.asarray(bounds, dtype=np.float64).tolist(),
        'tileSizeReferenceUnits': float(tile_size), 'tilesPerAxis': [len(e)-1 for e in edges],
        'tileQueries': query_count, 'rawReturnedIDs': raw_count, 'uniqueOriginalIDs': len(original),
        'largestTileReturnedIDs': largest, 'resourceCaps': {'tiles': max_tiles, 'rawIDs': max_raw_ids, 'uniqueIDs': unique_cap},
        'queryWallSeconds': time.monotonic()-started, 'originalGeometryChanged': False,
        'sameSortedGroundCandidateSemantics': True, 'perTickCollisionOrderChanged': False,
        'outsideQueryClampingPreserved': True, 'physicalAuthority': False}
