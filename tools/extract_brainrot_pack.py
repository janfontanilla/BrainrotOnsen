"""Extracts the game's 20 brainrot models from the third-party "Brainrot Models"
pack (by Agus_Fellini2) into assets/Brainrots.rbxmx, which Rojo syncs to
ReplicatedStorage.Assets.Brainrots.

Usage (from the project root):
    1. Convert the pack to Roblox XML with Rojo (a temp project that mounts it):
         {"name": "Inspect", "tree": {"$className": "DataModel",
           "Workspace": {"$className": "Workspace", "Pack": {"$path": "pack.rbxm"}}}}
         rojo build inspect.project.json -o pack.rbxlx
    2. python tools/extract_brainrot_pack.py pack.rbxlx assets/Brainrots.rbxmx

What it does:
    * keeps only the "Normal" variant of the models in TIER_MODELS, renamed Tier1..Tier20
    * deletes every Script / LocalScript / ModuleScript (the pack's own idle script)
    * deletes PointLights (80 lights per plot is too heavy); ParticleEmitters stay
    * keeps the AnimationController + Anims/Idle so an idle animation can be played
The tier -> pack model mapping lives here; tier 19 has no exact match in the pack.
"""

import sys
import copy
import xml.etree.ElementTree as ET

# Tier -> model name inside the pack's "Normal" folder.
TIER_MODELS = {
    1: "Tim Cheese",
    2: "Trippi Troppi",
    3: "Boneca Ambalabu",
    4: "Frigo Camelo",
    5: "Lirili Larila",
    6: "Chimpanzini Bananini",
    7: "Brr Brr Patapim",
    8: "Bombombini Gusini",
    9: "Cappuccino Assassino",
    10: "Ballerina Cappuccina",
    11: "Bombardiro Crocodilo",
    12: "Tralalero Tralala",
    13: "Tung Sahur",
    14: "La Vacca Saturno Saturnita",
    15: "Glorbo Fruttodrillo",
    16: "Cocofanto Elefanto",
    17: "Odin Din Din Dun",
    18: "Girafa Celeste",
    19: "Gorillo Watermelondrillo",  # substitute: the pack has no Tigrrullini Watermellini
    20: "Los Tralaleritos",
}

REMOVE_CLASSES = {"Script", "LocalScript", "ModuleScript", "PointLight"}


def name_property(item):
    props = item.find("Properties")
    if props is None:
        return None
    for p in props:
        if p.get("name") == "Name":
            return p
    return None


def prune(item):
    for child in list(item.findall("Item")):
        if child.get("class") in REMOVE_CLASSES:
            item.remove(child)
        else:
            prune(child)


def main(src, dst):
    root = ET.parse(src).getroot()
    workspace = next(i for i in root.findall("Item") if i.get("class") == "Workspace")
    pack = workspace.findall("Item")[0]
    normal = next(i for i in pack.findall("Item") if name_property(i) is not None and name_property(i).text == "Normal")
    by_name = {name_property(m).text: m for m in normal.findall("Item")}

    out_root = ET.Element("roblox", {"version": "4"})
    folder = ET.SubElement(out_root, "Item", {"class": "Folder", "referent": "BRAINROTS"})
    props = ET.SubElement(folder, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = "Brainrots"

    for tier, model_name in TIER_MODELS.items():
        model = copy.deepcopy(by_name[model_name])
        name_property(model).text = f"Tier{tier}"
        prune(model)
        folder.append(model)

    shared = root.find("SharedStrings")
    if shared is not None:
        out_root.append(shared)

    # Every Ref must point at an Item that is still there.
    present = {i.get("referent") for i in out_root.iter("Item")}
    for ref in out_root.iter("Ref"):
        if ref.text and ref.text != "null" and ref.text not in present:
            ref.text = "null"

    ET.indent(out_root, space="  ")
    ET.ElementTree(out_root).write(dst, encoding="utf-8")
    print(f"Wrote {dst}: {len(TIER_MODELS)} models")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
