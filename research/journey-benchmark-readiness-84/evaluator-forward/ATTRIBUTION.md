# Experimental navigation test data — MuSHRoom Koivu

Unchanged mirrors of two publicly released research archives by **Xuqian Ren**:

- **iPhone dataset (Basic Data)**, 2023-11-30, [Zenodo 10230733](https://zenodo.org/records/10230733), DOI [10.5281/zenodo.10230733](https://doi.org/10.5281/zenodo.10230733): `koivu_iphone.tar.gz`, 146,575,749 bytes.
- **Reference Mesh and Point Cloud**, 2023-11-29, [Zenodo 10222321](https://zenodo.org/records/10222321), DOI [10.5281/zenodo.10222321](https://doi.org/10.5281/zenodo.10222321): `koivu_mesh_pd.tar.gz`, 455,583,916 bytes.

Both exact records declare **Creative Commons Attribution 4.0 International (CC BY 4.0)**: [license](https://creativecommons.org/licenses/by/4.0/), [legal code](https://creativecommons.org/licenses/by/4.0/legalcode.en). Archive bytes and names are unchanged. No endorsement by the creators is implied. This attribution and the original license notices must accompany redistribution; license permissions do not remove other applicable rights.

Dataset/paper attribution: Xuqian Ren, Wenjia Wang, Dingding Cai, Tuuli Tuominen, Juho Kannala and Esa Rahtu, **MuSHRoom: Multi-Sensor Hybrid Room Dataset for Joint 3D Reconstruction and Novel View Synthesis**, WACV 2024. [Official repository](https://github.com/TUTvision/MuSHRoom), [paper](https://openaccess.thecvf.com/content/WACV2024/papers/Ren_MuSHRoom_Multi-Sensor_Hybrid_Room_Dataset_for_Joint_3D_Reconstruction_and_WACV_2024_paper.pdf).

`assets.json` pins the official acquisition URLs, lengths and independently computed SHA-256 checksums. `SHA256SUMS.txt` covers both archives. The mirror job hashes the original downloads and verifies GitHub's remote asset digest and size; no archive is extracted or executed.

These public research inputs are distinct from private app camera frames or family/home memory, which must never be uploaded. The FARO reference is evaluator-only; it is not an estimator input or live clearance. Phone reconstruction/recorded poses and a reference comparison do not establish live localization, complete obstacle detection, navigation safety or an app release.

## Stage 84 evaluator-forward modifications

This continuation selectively extracts the original Koivu FARO mesh and iPhone registration only, retains original topology and file hashes, derives per-pair floor-membership annotations under the documented historical classifier, and records synthetic actor trajectories. The original dataset files are unchanged. Derived labels are evaluator assumptions, not ground-truth semantic floor or live phone clearance. VTK's existing reader uses float coordinates in memory despite the original PLY's double coordinates; this inherited conversion is reported in every mesh receipt. No endorsement by the dataset authors is implied. No private participant or user-camera data is included.
