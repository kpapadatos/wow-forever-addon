"""Crop the newest WoW Forever screenshot around the addon window: python tools/lastshot.py OUT.png [x0 y0 x1 y1 as fractions]"""
import glob, os, sys
from PIL import Image
shots = glob.glob(r"C:\Program Files (x86)\World of Warcraft\_classic_beta_\Screenshots\*")
f = max(shots, key=os.path.getmtime)
im = Image.open(f)
box = [float(v) for v in sys.argv[2:6]] or [0.37, 0.17, 0.63, 0.79]
w, h = im.size
c = im.crop((int(w * box[0]), int(h * box[1]), int(w * box[2]), int(h * box[3])))
c.save(sys.argv[1])
print(f, im.size, c.size)
