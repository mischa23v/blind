# Currency ZIP — private Mac transfer

Download all eight assets from this private release into the same folder:
https://github.com/mischa23v/blind/releases/tag/currency-transfer-20261022

Open Terminal in that folder and run:

```sh
shasum -a 256 -c PART_SHA256SUMS
cat 7sys44td9c-1.zip.part00 7sys44td9c-1.zip.part01 7sys44td9c-1.zip.part02 7sys44td9c-1.zip.part03 > 7sys44td9c-1.zip
shasum -a 256 -c ORIGINAL_SHA256SUMS
```

Then open 7sys44td9c-1.zip on the Mac. Its only entry is another ZIP,
`7sys44td9c-1/Saudi Currency.zip`; open that archive for the dataset.
Keep enough free disk space for downloaded parts, the reassembled ZIP and extracted
data. Downloaded parts plus reassembled ZIP occupy about 13.5 GB, before extraction.
Do not remove parts until the original ZIP checksum passes.

This transfers the original user-provided archive unchanged. No training or image
processing was run. Dataset licensing, labels and suitability for currency training
have not been evaluated in this transfer.
