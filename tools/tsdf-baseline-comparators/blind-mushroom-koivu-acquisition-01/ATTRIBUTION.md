# MuSHRoom Koivu iPhone asset — attribution and provenance

Dataset: **MuSHRoom**, Xuqian Ren, Wenjia Wang, Dingding Cai, Tuuli Tuominen, Juho Kannala and Esa Rahtu, WACV 2024. [Original paper](https://openaccess.thecvf.com/content/WACV2024/papers/Ren_MuSHRoom_Multi-Sensor_Hybrid_Room_Dataset_for_Joint_3D_Reconstruction_and_WACV_2024_paper.pdf), [official repository](https://github.com/TUTvision/MuSHRoom).

Exact source: Xuqian Ren, **iPhone dataset (Basic Data)**, published 2023-11-30, [Zenodo record 10230733](https://zenodo.org/records/10230733), DOI [10.5281/zenodo.10230733](https://doi.org/10.5281/zenodo.10230733). The public record declares **Creative Commons Attribution 4.0 International**: [license](https://creativecommons.org/licenses/by/4.0/), [legal code](https://creativecommons.org/licenses/by/4.0/legalcode.en). Original record metadata is retained in `zenodo-record-10230733.json`.

File: `koivu_iphone.tar.gz`, 146,575,749 bytes. Published MD5 `a359dba714e7829be11747ce5dee141c` matched. Acquired archive SHA-256 `68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518`. MD5 comparison is not an authenticity guarantee; provenance is the official HTTPS record plus retained hashes/metadata.

The original paper identifies iPhone 12 Pro Max capture with Polycam. The phone-reconstructed mesh is **not the Faro reference scan**, and the official README warns that it is not aligned with the accompanying camera poses. Do not claim recorded RGB-D replay, native online localization, complete geometry or physical safety from synthetic rendering in this mesh.

Changes so far: none to archive contents. If selective extraction is performed, exact member names and hashes are recorded separately. Any later coordinate transform, mesh conversion or rendering must be documented as a modification and must not imply endorsement by the dataset authors. No account, gated terms acceptance, paired Faro archive or point-cloud download was used.
