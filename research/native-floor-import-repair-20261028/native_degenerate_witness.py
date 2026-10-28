#!/usr/bin/env python3
"""Recount exact degeneracy from the retained digest-bound native parity bits."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

def digest(data):
    return hashlib.sha256(data).hexdigest()

def decode(bits):
    values = [struct.unpack('<f', struct.pack('<I', word))[0] for word in bits]
    return [values[i:i+3] for i in range(0, len(values), 3)]

def normal(points):
    a, b, c = points
    u, v = [b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)]
    return [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]

def duplicate(points):
    a, b, c = points
    return a == b or b == c or c == a

def inspect(root):
    manifest_bytes = (root/'APPLE_ROOM_ROUTE_SAME_EXPORT_MANIFEST.json').read_bytes()
    manifest = json.loads(manifest_bytes)
    inventory_bytes = (root/manifest['inventoryAttachmentName']).read_bytes()
    assert digest(inventory_bytes) == manifest['inventorySHA256']
    inventory = json.loads(inventory_bytes)
    result = {'schema': 1, 'source_commit': 'fa43366dced02c8e578baf4d38d69caa10614718',
              'native_run': 40765137795, 'physicalAuthority': False,
              'manifest_sha256': digest(manifest_bytes), 'inventory_sha256': digest(inventory_bytes),
              'fixtures': []}
    for fixture in inventory['fixtures']:
        row = {'fixture': fixture['fixtureID'], 'triangles': 0, 'witnesses': []}
        for mesh in fixture['meshParity']['meshes']:
            local, world = decode(mesh['localPositionBits']), decode(mesh['worldPositionBits'])
            indices = mesh['triangleIndices']
            valid_positions = set()
            invalid = []
            for face in range(len(indices)//3):
                triangle = indices[3*face:3*face+3]
                local_triangle, world_triangle = [[points[i] for i in triangle] for points in [local, world]]
                row['triangles'] += 1
                if all(component == 0 for component in normal(world_triangle)):
                    invalid.append({'node_index': mesh['nodeIndex'], 'feature_id': mesh['featureID'],
                                    'face_index': face, 'indices': triangle,
                                    'local': local_triangle, 'world': world_triangle,
                                    'local_exact_duplicate': duplicate(local_triangle),
                                    'world_exact_duplicate': duplicate(world_triangle),
                                    'local_zero_area': all(component == 0 for component in normal(local_triangle))})
                else:
                    valid_positions.update(map(tuple, world_triangle))
            for witness in invalid:
                witness['all_positions_retained_by_valid_same_mesh_faces'] = all(tuple(p) in valid_positions for p in witness['world'])
            row['witnesses'].extend(invalid)
        row['zero_area_count'] = len(row['witnesses'])
        result['fixtures'].append(row)
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('artifact_root', type=Path)
    args = parser.parse_args()
    print(json.dumps(inspect(args.artifact_root), indent=2))
