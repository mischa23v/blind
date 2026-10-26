# Public fixture attribution and modifications

Geometry source: MuSHRoom, Xuqian Ren, Wenjia Wang, Dingding Cai, Tuuli Tuominen,
Juho Kannala and Esa Rahtu, WACV2024. Official project:
https://github.com/TUTvision/MuSHRoom
Dataset iPhone Basic Data: https://zenodo.org/records/10230733
DOI https://doi.org/10.5281/zenodo.10230733
License CC BY4.0: https://creativecommons.org/licenses/by/4.0/

koivu_iphone.tar.gz published146,575,749bytes; original acquired SHA256
68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518.
Original author Polycam OBJ SHA256
79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1.
Capture is reported iPhone12ProMax. No FARO reference or private photos included.

Modifications: extract geometry only; existing stage37 phone-only proper rigid
rotation/translation with fixed scale1; convert to +Y-up native game coordinates;
32 synthetic local-coordinate tile transforms with duplicate boundary vertices;
retain route-query coordinates and frozen manually assisted tabletop unknown
exclusion from65 for candidate tests; serialize compact JSON and gzip. All29,366
source triangles retained. No new floor, obstacle shape or free-space guarantee.
This is a fused mesh derivative, not a live ARKit recording. No endorsement by
original authors implied. Fixture metadata/pins retain exact derivative hashes.

Native engine: RecastNavigation https://github.com/recastnavigation/recastnavigation
revision9f4ce64458dfae86e1239c525ddc219c4e9e06f1, Zlib license in
native/RECAST_LICENSE.txt. Unmodified existing repository upstream sources are
verified individually against SOURCE_PINS.json and reused without downloads.
The local stage66 adapter is copied with one include-path change only; original
and copied source hashes are recorded in PROVENANCE.json. Swift sources are
byte-identical to reviewed stage70. The Apple binary is newly built, never a
Linux .so renamed or shipped as an Apple library.
