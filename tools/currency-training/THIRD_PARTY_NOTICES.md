# Provenance and third-party notices

## Microsoft BankNote-Net

Project: https://github.com/microsoft/banknote-net

Paper: Felipe Oviedo, Srinivas Vinnakota, Eugene Seleznev, Hemant Malhotra,
Saqib Shaikh and Juan Lavista Ferres, “BankNote-Net: Open Dataset for Assistive
Currency Recognition” (2022), https://arxiv.org/abs/2204.03738.

Microsoft's repository code is MIT licensed. Its README section “License for
Dataset and Model” points to CDLA-Permissive-2.0 for the dataset and warns not to
reconstruct high-resolution banknote images from embeddings. Preserve applicable
upstream copyright/license files alongside any distributed upstream materials.

- MIT source notice: https://github.com/microsoft/banknote-net/blob/main/LICENSE
- Dataset/model notice: https://github.com/microsoft/banknote-net#license-for-dataset-and-model
- CDLA-Permissive-2.0: https://cdla.dev/permissive-2-0/

This adapter implements an independent small scikit-learn head plus temperature
calibration rather than copying upstream's two-layer train_custom.py trainer.
It uses the upstream pretrained encoder, 224×224 RGB input and 1/255 scaling.
No encoder file or upstream training-image assets are bundled in this directory.

## Saudi Currency Dataset

Maruf, Nazmul Ahasan; Basuhail, Abdullah; Adil, AHM (2022), “Saudi Currency
Dataset”, Mendeley Data, V1, doi: 10.17632/7sys44td9c.1.

Source: https://data.mendeley.com/datasets/7sys44td9c/1

Stated license: Creative Commons Attribution 4.0 International:
https://creativecommons.org/licenses/by/4.0/

If used, preserve attribution, license link and a change notice such as:
“Images were cropped using provided annotations, resized and encoded for
experimental denomination classification.” No dataset images are bundled here.
The archive contents and any embedded additional notices remain uninspected.

## Currency reproduction is a separate issue

Saudi Central Bank rules:
https://sama.gov.sa/en-US/MediaCenter/News/Pages/News20071024.aspx

The rules describe prior permission and conditions for currency-image
reproduction, including digital uses. A contributor's CC BY declaration does
not settle all regulatory permissions. This preparation does not redistribute
the photographs, assert permission, or give a legal conclusion about training.
Clarify the intended publishing/reproduction scope before distributing images.

## Export framework

Apple Core ML Tools documentation:
https://apple.github.io/coremltools/docs-guides/source/tensorflow-2.html

TensorFlow, Pillow, NumPy, SciPy, scikit-learn, h5py, threadpoolctl and coremltools
retain their own package licenses. This directory does not vendor those packages.
