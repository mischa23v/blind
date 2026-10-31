"""Pure standard-library pose contract. No mapper, array package, or native import.

MuSHRoom 3f36dbf iphone_tools/1_nerfstudio_to_sdfstudio_within.py
uses OpenGL camera-to-world and negates camera columns Y/Z for CV.
The supplied world axes are already converted: never permute them again.
"""
import math

D = ((1., 0., 0., 0.), (0., -1., 0., 0.),
     (0., 0., -1., 0.), (0., 0., 0., 1.))
RIGID_TOLERANCE = 2e-6  # numerical float32-source tolerance, not physical accuracy


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def validate_pose(pose):
    require(isinstance(pose, (list, tuple)) and len(pose) == 4,
            'missing or invalid 4x4 camera-to-world pose')
    require(all(isinstance(row, (list, tuple)) and len(row) == 4 for row in pose),
            'invalid 4x4 camera-to-world rows')
    require(all(finite_number(x) for row in pose for x in row), 'nonfinite/nonnumeric pose')
    p = tuple(tuple(float(x) for x in row) for row in pose)
    require(p[3] == (0., 0., 0., 1.), 'nonhomogeneous pose')
    r = [row[:3] for row in p[:3]]
    for i in range(3):
        for j in range(3):
            gram = sum(r[k][i] * r[k][j] for k in range(3))
            require(abs(gram - float(i == j)) <= RIGID_TOLERANCE,
                    'pose rotation is not rigid; no automatic repair')
    det = (r[0][0]*(r[1][1]*r[2][2]-r[1][2]*r[2][1])
           -r[0][1]*(r[1][0]*r[2][2]-r[1][2]*r[2][0])
           +r[0][2]*(r[1][0]*r[2][1]-r[1][1]*r[2][0]))
    require(abs(det - 1.) <= RIGID_TOLERANCE, 'pose reflection or invalid determinant')
    return p


def camera_cv_to_saved_world(pose):
    p = validate_pose(pose)
    # T_frame @ D: camera basis change on the RIGHT, including no world row change.
    return tuple(tuple(p[i][j] * D[j][j] for j in range(4)) for i in range(4))


def transform_point(transform, point):
    t = validate_pose(transform)
    require(isinstance(point, (list, tuple)) and len(point) == 3 and
            all(finite_number(x) for x in point), 'invalid XYZ point')
    return transform_coordinates(point[0], point[1], point[2], t)


def inverse_rigid(transform):
    t = validate_pose(transform)
    r = tuple(tuple(t[j][i] for j in range(3)) for i in range(3))
    return tuple(r[i] + (-sum(r[i][j] * t[j][3] for j in range(3)),)
                 for i in range(3)) + ((0., 0., 0., 1.),)


def frame_contract(frame):
    require(isinstance(frame, dict), 'missing frame')
    require(frame.get('w') == 738 and frame.get('h') == 994, 'original raster required')
    for name in ('fl_x', 'fl_y', 'cx', 'cy'):
        require(finite_number(frame.get(name)), 'missing/nonfinite original intrinsic: ' + name)
    require(frame['fl_x'] > 0 and frame['fl_y'] > 0, 'invalid focal length')
    p = validate_pose(frame.get('transform_matrix'))
    t = camera_cv_to_saved_world(p)
    return t, tuple(p[i][3] for i in range(3))


def transform_coordinates(x, y, z, transform):
    """Same arithmetic for scalar controls and full-raster array columns."""
    t = validate_pose(transform)
    return tuple(t[i][0]*x + t[i][1]*y + t[i][2]*z + t[i][3]
                 for i in range(3))
