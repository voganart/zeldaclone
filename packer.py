import os
from PIL import Image
import sys

# --- НАСТРОЙКИ ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.join(SCRIPT_DIR, "assets/textures/environment/")

SUFFIX_ALBEDO_BUMP = "_AlbedoBump.png"
SUFFIX_NORMAL_ROUGH = "_NormalRoughness.png"
SUFFIX_METALLIC_AO = "_MetallicAO.png"

KEYWORDS = {
    "albedo": ["albedo", "basecolor", "diffuse", "color", "col"],
    "normal": ["normal", "nrm", "norm"],
    "roughness": ["roughness", "rough", "rgh"],
    "height": ["height", "displacement", "disp", "bump", "h"],
    "metallic": ["metallic", "metalness"],
    "ao": ["ao", "ambientocclusion", "ambient_occlusion", "occlusion"]
}
IGNORE_KEYWORDS = ["packed", "import", "preview", "mask", "orm"]

def find_texture(files, type_keywords):
    for f in files:
        lower_f = f.lower()
        is_ignored = any(ignore_word in lower_f for ignore_word in IGNORE_KEYWORDS)
        if is_ignored:
            continue
            
        for keyword in type_keywords:
            if keyword == "metallic" and "metallic" not in lower_f and "metal" in lower_f:
                continue
            if keyword in lower_f:
                return f
    return None

def process_folder(dir_path, files):
    print(f"Processing folder: {dir_path}")

    found_maps = {}
    for key, keywords in KEYWORDS.items():
        found_maps[key] = find_texture(files, keywords)
    
    if not found_maps["albedo"] and not found_maps["normal"]:
        print("  Skipping (no albedo or normal found).")
        return

    used_files = set()
    folder_name = os.path.basename(os.path.normpath(dir_path))
    
    resolution = None
    if found_maps["albedo"]:
        try:
            resolution = Image.open(os.path.join(dir_path, found_maps["albedo"])).size
        except Exception as e:
            print(f"  ERROR: Could not open albedo image {found_maps['albedo']}: {e}")
            return
    elif found_maps["normal"]:
        try:
            resolution = Image.open(os.path.join(dir_path, found_maps["normal"])).size
        except Exception as e:
            print(f"  ERROR: Could not open normal image {found_maps['normal']}: {e}")
            return
    else:
        print(f"  Skipping {folder_name}, couldn't determine resolution.")
        return

    # --- Упаковка Albedo + Height ---
    albedo_img = Image.open(os.path.join(dir_path, found_maps["albedo"])).convert("RGB").resize(resolution) if found_maps["albedo"] else Image.new("RGB", resolution, (0,0,0))
    height_img = Image.open(os.path.join(dir_path, found_maps["height"])).convert("L").resize(resolution) if found_maps["height"] else Image.new("L", resolution, 255)
    
    img1 = Image.new("RGBA", resolution)
    img1.paste(albedo_img, (0,0))
    img1.putalpha(height_img)
    img1.save(os.path.join(dir_path, folder_name + SUFFIX_ALBEDO_BUMP))
    print(f"  Saved {folder_name + SUFFIX_ALBEDO_BUMP}")
    if found_maps["albedo"]: used_files.add(found_maps["albedo"])
    if found_maps["height"]: used_files.add(found_maps["height"])

    # --- Упаковка Normal + Roughness ---
    normal_img = Image.open(os.path.join(dir_path, found_maps["normal"])).convert("RGB").resize(resolution) if found_maps["normal"] else Image.new("RGB", resolution, (128, 128, 255))
    roughness_img = Image.open(os.path.join(dir_path, found_maps["roughness"])).convert("L").resize(resolution) if found_maps["roughness"] else Image.new("L", resolution, 255)

    img2 = Image.new("RGBA", resolution)
    img2.paste(normal_img, (0,0))
    img2.putalpha(roughness_img)
    img2.save(os.path.join(dir_path, folder_name + SUFFIX_NORMAL_ROUGH))
    print(f"  Saved {folder_name + SUFFIX_NORMAL_ROUGH}")
    if found_maps["normal"]: used_files.add(found_maps["normal"])
    if found_maps["roughness"]: used_files.add(found_maps["roughness"])
    
    # --- Упаковка Metallic + AO ---
    if found_maps["metallic"] or found_maps["ao"]:
        metallic_img = Image.open(os.path.join(dir_path, found_maps["metallic"])).convert("L").resize(resolution) if found_maps["metallic"] else Image.new("L", resolution, 0)
        ao_img = Image.open(os.path.join(dir_path, found_maps["ao"])).convert("L").resize(resolution) if found_maps["ao"] else Image.new("L", resolution, 255)
        
        r, g, b = (metallic_img, ao_img, Image.new("L", resolution, 0))
        final_mao = Image.merge("RGB", (r, g, b))
        final_mao.save(os.path.join(dir_path, folder_name + SUFFIX_METALLIC_AO))
        print(f"  Saved {folder_name + SUFFIX_METALLIC_AO}")
        if found_maps["metallic"]: used_files.add(found_maps["metallic"])
        if found_maps["ao"]: used_files.add(found_maps["ao"])

    # --- Удаление исходников ---
    for file_to_delete in used_files:
        try:
            os.remove(os.path.join(dir_path, file_to_delete))
            print(f"  Deleted source: {file_to_delete}")
        except OSError as e:
            print(f"  Error deleting {file_to_delete}: {e}")


def main():
    print("--- STARTING PYTHON TEXTURE PACKER ---")
    if not os.path.isdir(ROOT_DIR):
        print(f"ERROR: Directory not found: {ROOT_DIR}")
        print(f"Please make sure 'packer.py' is in the project's root folder ('zeldaclone/').")
        return

    for root, dirs, files in os.walk(ROOT_DIR):
        # !! ИСПРАВЛЕНИЕ: УБРАНА СТРОКА, КОТОРАЯ ФИЛЬТРОВАЛА ПАПКИ !!
        
        files_to_process = [f for f in files if not (
            f.lower().endswith(SUFFIX_ALBEDO_BUMP.lower()) or
            f.lower().endswith(SUFFIX_NORMAL_ROUGH.lower()) or
            f.lower().endswith(SUFFIX_METALLIC_AO.lower()) or
            f.lower().endswith(".tres"))
        ]
        
        if files_to_process:
            process_folder(root, files_to_process)
            
    print("--- PYTHON SCRIPT FINISHED ---")

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding='utf-8')
    main()