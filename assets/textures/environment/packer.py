import os
from PIL import Image

# --- НАСТРОЙКИ ---
# Какие слова искать в названиях файлов (все в нижнем регистре)
KEYWORDS = {
    "albedo": ["color", "albedo", "diffuse", "basecolor", "baseColor"],
    "ao": ["ao", "ambient", "occlusion", "ambient_occlusion", "ambientocclusion", "ambientOcclusion"],
    "roughness": ["roughness", "rough"],
    "metallic": ["metal", "metallic", "metalness"],
    "normal_gl": ["normal_gl", "normalgl", "normal"], # Приоритет OpenGL
    "normal_dx": ["normal_dx", "normaldx"], # DirectX (удаляем)
    "delete": ["height", "displacement", "bump", "normal_dx", "normaldx"]
}

def process_directory(root_dir):
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Пропускаем, если в папке нет картинок
        images = [f for f in filenames if f.lower().endswith(('.png', '.jpg', '.jpeg', '.tga'))]
        if not images:
            continue

        print(f"Processing: {dirpath}")
        
        files_map = {}
        
        # 1. Классификация файлов
        for img in images:
            lower_name = img.lower()
            
            # Определяем тип файла
            for key, words in KEYWORDS.items():
                if any(w in lower_name for w in words):
                    # Особая проверка для нормалей, чтобы не путать GL и DX
                    if key == "normal_gl" and ("dx" in lower_name or "directx" in lower_name):
                        continue
                    files_map[key] = os.path.join(dirpath, img)
                    break
        
        # 2. Упаковка ORM (AO, Roughness, Metal)
        if "roughness" in files_map:
            try:
                # Открываем Roughness (обязательно)
                rough_img = Image.open(files_map["roughness"]).convert("L")
                width, height = rough_img.size
                
                # Открываем AO (если нет - заливаем белым)
                if "ao" in files_map:
                    ao_img = Image.open(files_map["ao"]).convert("L")
                    # Ресайз если размер не совпадает
                    if ao_img.size != rough_img.size: ao_img = ao_img.resize(rough_img.size)
                else:
                    ao_img = Image.new("L", (width, height), 255) # Белый (нет теней)

                # Открываем Metal (если нет - заливаем черным)
                if "metallic" in files_map:
                    metal_img = Image.open(files_map["metallic"]).convert("L")
                    if metal_img.size != rough_img.size: metal_img = metal_img.resize(rough_img.size)
                else:
                    metal_img = Image.new("L", (width, height), 0) # Черный (не металл)

                # Собираем каналы: R=AO, G=Roughness, B=Metal !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                orm_img = Image.merge("RGB", (ao_img, rough_img, metal_img))
                
                # Сохраняем
                save_name = os.path.join(dirpath, "Packed_ORM.png")
                orm_img.save(save_name)
                print(f"  [+] Created ORM: {save_name}")
                
                # Добавляем исходники в список на удаление (если хочешь удалить исходники)
                # Если боишься, закомментируй строки ниже
                if "ao" in files_map: os.remove(files_map["ao"])
                if "roughness" in files_map: os.remove(files_map["roughness"])
                if "metallic" in files_map: os.remove(files_map["metallic"])
                
            except Exception as e:
                print(f"  [!] Error packing ORM: {e}")

        # 3. Удаление лишнего (Height, DX Normal)
        for img in images:
            lower_name = img.lower()
            # Если файл есть в списке на удаление
            if any(w in lower_name for w in KEYWORDS["delete"]):
                full_path = os.path.join(dirpath, img)
                if os.path.exists(full_path):
                    os.remove(full_path)
                    print(f"  [-] Deleted: {img}")

# Запуск в текущей папке
if __name__ == "__main__":
    # ИСПРАВЛЕНИЕ: Теперь мы берем путь к папке, где лежит САМ СКРИПТ
    current_folder = os.path.dirname(os.path.abspath(__file__))
    
    print(f"Script location: {current_folder}")
    confirm = input(f"Start processing in THIS folder? (y/n): ")
    
    if confirm.lower() == 'y':
        process_directory(current_folder)
        print("Done!")
    else:
        print("Cancelled.")