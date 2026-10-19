"""Render one revised home and workshop for approval; only writes to the candidate folder."""
from __future__ import annotations
import io, json, sys, time, urllib.parse, urllib.request
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[4]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/"pipeline/art"))
import generate as art

MANIFEST=json.loads((HERE/"comfyui-manifest.json").read_text())
ASSETS={a["id"]:a for a in MANIFEST["assets"]}
COMFY=MANIFEST.get("comfy_url","http://127.0.0.1:8188").rstrip("/")
OUT=HERE/"quality-comparison"
OUT.mkdir(exist_ok=True)

def get(url): return json.loads(urllib.request.urlopen(url,timeout=30).read())
def render(job, guide, stack="pixel-art-only"):
    control=art.upload_image(COMFY,guide.convert("RGB"),f"rootward-quality-guide-{job['id']}.png")
    init=art.layout_sketch(job)
    init_name=art.upload_image(COMFY,init,f"rootward-quality-init-{job['id']}.png") if init else None
    graph=art.build_graph(job,f"rootward-art/quality-{job['id']}",control,init_name)
    prompt_id=art.http_json(f"{COMFY}/prompt",{"prompt":graph,"client_id":"rootward-building-quality"})["prompt_id"]
    t=time.monotonic()
    while True:
        entry=get(f"{COMFY}/history/{prompt_id}").get(prompt_id)
        if entry and entry.get("status",{}).get("status_str")=="error":
            raise RuntimeError(json.dumps(entry["status"])[:3000])
        if entry and entry.get("status",{}).get("completed"): break
        if time.monotonic()-t>1200: raise TimeoutError(prompt_id)
        time.sleep(1)
    ims=[]
    for n in ("8","11"):
        it=entry["outputs"][n]["images"][0]
        query=urllib.parse.urlencode({"filename":it["filename"],"subfolder":it["subfolder"],"type":it["type"]})
        ims.append(Image.open(io.BytesIO(urllib.request.urlopen(f"{COMFY}/view?{query}",timeout=120).read())).copy())
    rgba=ims[0].convert("RGBA"); rgba.putalpha(ims[1].convert("L"))
    rgba.save(OUT/f"{job['id']}-source.png",optimize=True)
    processed=art.process(job,np.asarray(rgba,dtype=np.float32)/255.0)[0][1]
    processed.save(OUT/f"{job['id']}-fitted.png",optimize=True)
    return processed

home=art.resolve(ASSETS["home-front-plane-v4"],MANIFEST["styles"])
home["id"]="home-quality-v4"
home["out"]="Concept/v0.35/building-architecture/comfyui-candidates/quality-comparison/home"
home["seed"]=20261027; home["width"]=1024; home["height"]=1024
home["init"]={"image":MANIFEST["_reference"],"denoise":0.42,"matte":"#ffffff"}
home["control"]={"model":"t2i-adapter_diffusers_xl_lineart.safetensors","strength":0.52,"start":0.0,"end":0.72}
home["prompt"]=("high quality hand-detailed pixel art in the exact camera and palette family of the supplied V4 reference, "
"single cozy timber cottage viewed cardinal top-down from the south, broad flat front facade only, front door facing screen-bottom, "
"rear roof apex at top-center with a distinct ridge receding toward the centered front gable, paired blue-violet slate roof planes "
"expanding toward front eaves, individual overlapping irregular shingle clusters with deep ink outlines and subtle per-tile color variation, "
"layered warm amber timber planks with staggered joins, pale individually blocked stone foundation and arch, round front gable window, "
"two small facade windows, rear chimney, compact natural variation, sharp clustered pixels, crisp dark plum outline, isolated single building")
home["negative"] += ", flat roof, horizontal roof cap, broad horizontal roof stripes, smooth gradients, photorealism, soft focus, blurry edges, side wall, visible side elevation"

work=art.resolve(ASSETS["workshop-front-plane-v4"],MANIFEST["styles"])
work["id"]="workshop-lineart-only-v4"
work["out"]="Concept/v0.35/building-architecture/comfyui-candidates/quality-comparison/workshop-lineart-only"
work["seed"]=20261029; work["width"]=1152; work["height"]=960
work["init"]=None
work["control"]={"model":"t2i-adapter_diffusers_xl_lineart.safetensors","strength":0.86,"start":0.0,"end":0.92}
work["prompt"]=("high quality hand-detailed pixel art in the exact camera and palette family of the supplied V4 reference, "
"single very broad low village tinker's workshop, strict cardinal overhead game camera looking toward the south/front, with only one broad flat front facade visible, "
"no side elevation, no side walls, roof rear apex centered at top and a strong ridge receding to the centered front gable, "
"two paired teal roof planes spreading diagonally toward broad front eaves, distinct overlapping irregular teal shingle clusters, "
"subtle individual tile color variation and deep dark plum outlines, broad uninterrupted amber timber front facade with short staggered plank seams, "
"thin pale stone footing, extra-wide centered rectangular double work doors occupying most of the facade, two clear door leaves with a central seam, "
"visible small hammer, saw and tongs mounted flat on the front beside the doors, tiny roof vent only, no chimney, "
"sharply clustered pixels, textured handmade pixel-art detail, clear working identity, isolated single building, transparent background")
work["negative"] += ", flat roof, horizontal roof cap, broad horizontal roof stripes, cottage, family home, stone arch, stone gable patch, chimney, fireplace, giant masonry, side wall, visible side elevation, side windows, isometric, frontal eye-level view, roof overhang covering door"

results=[]
print(f"rendering {home['id']} denoise={home['init']['denoise']} control={home['control']['strength']}",flush=True)
home_guide=Image.open(OUT/"guides"/"home-v4-detail.png").convert("L")
home_fit=render(home,home_guide)
work_guide=Image.open(OUT/"guides"/"workshop-v4-detail.png").convert("L")
print(f"rendering {work['id']} no-init control={work['control']['strength']}",flush=True)
work_fit=render(work,work_guide)
work_low_init=dict(work)
work_low_init.update({"id":"workshop-low-init-v4","seed":20261030,"out":"Concept/v0.35/building-architecture/comfyui-candidates/quality-comparison/workshop-low-init"})
work_low_init["init"]={"image":MANIFEST["_reference"],"denoise":0.82,"matte":"#ffffff"}
print(f"rendering {work_low_init['id']} denoise=0.82 control={work_low_init['control']['strength']}",flush=True)
work_low_fit=render(work_low_init,work_guide)

# The review sheet compares the two fitted candidates, and the V4 reference fit to the same 240x240 frame.
ref=Image.open(ROOT/MANIFEST["_reference"]).convert("RGBA")
ref.resize((240,240),Image.Resampling.LANCZOS).save(OUT/"home-v4-reference-fitted.png")
art.contact_sheet([("V4 reference fit",Image.open(OUT/"home-v4-reference-fitted.png")),("home detail",home_fit),("workshop lineart only",work_fit),("workshop low V4 init",work_low_fit)],OUT/"revised-home-workshop-contact.png",cell=300)
print("contact:",OUT/"revised-home-workshop-contact.png")
