"""
Generates the addon's source art with Qwen-Image 2.1 on a local ComfyUI (http://127.0.0.1:8188).
Workflow mirrors E:\\comfyui\\generate.py. Outputs PNGs into art/gen/.

    python tools/gen_art.py [--only parchment,corner] [--steps 25]
"""
import argparse, json, os, sys, time, uuid, urllib.request, urllib.parse

UNET = "qwen_image_2.1_int8_convrot.safetensors"
CLIP = "qwen3vl_8b_int8_convrot.safetensors"
VAE = "qwen_image_2.1_vae_bf16.safetensors"
RGBA_PRE = "This is an RGBA format image with transparency. "
RGBA_POST = " The image has an alpha channel and a transparent background."

DUNGEON_STYLE = (" Epic fantasy digital painting in the style of World of Warcraft concept art, painterly brushwork, "
                 "dramatic lighting, rich saturated colours, wide cinematic composition, no text, no people in the foreground.")

JOBS = [
    {"id": "parchment", "w": 1024, "h": 1024, "seed": 11,
     "prompt": "A flat, evenly lit, top-down scan of a sheet of aged parchment paper filling the entire frame edge to edge. "
               "Warm cream and light tan tones, subtle fibres, faint mottled stains and soft blotches, very slightly darker "
               "vignette towards the edges. No text, no drawings, no folds, no objects, no border, no shadows. Seamless texture."},
    {"id": "corner", "w": 1024, "h": 1024, "seed": 22,
     "prompt": RGBA_PRE + "An ornate corner piece for a fantasy game user interface frame: polished antique gold metal "
               "filigree forming an L-shaped right angle bracket that occupies the top-left corner, with two arms running "
               "along the top edge and the left edge, scrollwork, a small embedded deep blue sapphire gem at the corner, "
               "engraved details, bevelled metallic highlights, World of Warcraft UI style. Only the corner ornament, the "
               "rest of the image empty." + RGBA_POST},
    {"id": "divider", "w": 1536, "h": 384, "seed": 33,
     "prompt": RGBA_PRE + "A long thin horizontal ornamental divider for a fantasy game interface: an engraved antique "
               "gold metal bar with a central diamond-shaped sapphire gem and symmetrical scrollwork flourishes tapering "
               "to points at both ends, World of Warcraft UI style, centred, perfectly symmetrical." + RGBA_POST},
    {"id": "dm", "w": 1024, "h": 512, "seed": 101,
     "prompt": "A vast underground goblin shipyard inside a cave: a huge wooden pirate ship docked in a cavern lagoon, "
               "lanterns, mining carts, wooden scaffolding, cannons, smoky warm torchlight." + DUNGEON_STYLE},
    {"id": "sfk", "w": 1024, "h": 512, "seed": 102,
     "prompt": "A dark gothic castle keep on a cliff at night under a full moon, crooked towers, glowing purple-lit windows, "
               "dead trees, wolves silhouetted, misty courtyard, haunted atmosphere." + DUNGEON_STYLE},
    {"id": "hot", "w": 1024, "h": 512, "seed": 103,
     "prompt": "An ancient dwarven hall carved inside a mountain: colossal stone statues of bearded dwarven kings, "
               "rivers of lava in channels, glowing runes, enormous forge braziers, golden light." + DUNGEON_STYLE},
    {"id": "rol", "w": 1024, "h": 512, "seed": 104,
     "prompt": "The ruined capital city of a fallen human kingdom: shattered white marble throne room open to a green "
               "plague-tinted sky, collapsed spires, sickly green fog, undead banners, giant spider webs." + DUNGEON_STYLE},
    {"id": "wc", "w": 1024, "h": 512, "seed": 107,
     "prompt": "A vast lush cavern of glowing green fissures: winding stone tunnels overgrown with giant ferns and "
               "luminous mushrooms, turquoise pools and waterfalls, druidic serpent statues, eerie green mist." + DUNGEON_STYLE},
    {"id": "sm", "w": 1024, "h": 512, "seed": 108,
     "prompt": "A grand crimson-bannered monastery cathedral interior: towering gothic stained glass windows with "
               "red and gold light, rows of candles, a fanatical crusade altar with a golden sun emblem." + DUNGEON_STYLE},
]


def call(host, path, data=None, raw=False):
    req = urllib.request.Request(f"http://{host}{path}", data=json.dumps(data).encode() if data is not None else None,
                                 headers={"Content-Type": "application/json"} if data is not None else {})
    with urllib.request.urlopen(req, timeout=600) as r:
        body = r.read()
    return body if raw else json.loads(body)


def workflow(job, steps):
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "2": {"class_type": "QwenImage21Cache", "inputs": {"model": ["1", 0], "device": "auto", "dtype": "default"}},
        "3": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "qwen_image", "device": "default"}},
        "4": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "5": {"class_type": "TextEncodeQwenImage21",
              "inputs": {"clip": ["3", 0], "prompt": job["prompt"], "negative_prompt": "", "resolution": 1024}},
        "7": {"class_type": "EmptyLatentImage", "inputs": {"width": job["w"], "height": job["h"], "batch_size": 1}},
        "6": {"class_type": "KSampler", "inputs": {"model": ["2", 0], "positive": ["5", 0], "negative": ["5", 1],
                                                   "latent_image": ["7", 0], "seed": job["seed"], "steps": steps,
                                                   "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple",
                                                   "denoise": 1.0}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["4", 0]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "simulacrum/" + job["id"]}},
    }


def run(host, wf, out_path):
    pid = call(host, "/prompt", {"prompt": wf, "client_id": uuid.uuid4().hex})["prompt_id"]
    t0 = time.time()
    while True:
        hist = call(host, f"/history/{pid}")
        if pid in hist:
            st = hist[pid].get("status", {})
            if st.get("status_str") == "error":
                raise RuntimeError(json.dumps(st.get("messages"), indent=1)[:3000])
            for out in hist[pid]["outputs"].values():
                for img in out.get("images", []):
                    q = urllib.parse.urlencode({k: img[k] for k in ("filename", "subfolder", "type")})
                    with open(out_path, "wb") as f:
                        f.write(call(host, f"/view?{q}", raw=True))
                    return time.time() - t0
        time.sleep(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1:8188")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "art", "gen"))
    ap.add_argument("--steps", type=int, default=25)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    only = set(filter(None, a.only.split(",")))
    for job in JOBS:
        if only and job["id"] not in only:
            continue
        out = os.path.join(a.out, job["id"] + ".png")
        print(f"[{job['id']}] ...", flush=True)
        print(f"   {run(a.host, workflow(job, a.steps), out):.1f}s -> {out}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
