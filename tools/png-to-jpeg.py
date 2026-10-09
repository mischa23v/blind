# Converts one dataset PNG frame to a bounded JPEG for the relay (which accepts JPEG only,
# like the phone sends). Run with `python -E` from tools/, so nothing is imported from the data folder.
import sys
from PIL import Image

source, target, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])
image = Image.open(source).convert("RGB")
image.thumbnail((limit, limit))
image.save(target, "JPEG", quality=80)
