# filename: preprocess_rgb_to_24bit_hex.py
from PIL import Image
import sys

def preprocess_bmp_rgb_to_24bit_hex(input_bmp_path, output_hex_path, target_width, target_height):
    try:
        img = Image.open(input_bmp_path)
    except FileNotFoundError:
        print(f"Error: Input BMP file '{input_bmp_path}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error opening or reading BMP file: {e}")
        sys.exit(1)

    # ตรวจสอบว่าเป็น RGB mode หรือไม่ ถ้าไม่ใช่ให้แปลงเป็น RGB
    if img.mode != 'RGB':
        print(f"Warning: Converting image from mode '{img.mode}' to 'RGB'")
        img = img.convert('RGB')

    # Resize if necessary
    if img.width != target_width or img.height != target_height:
        print(f"Warning: Resizing image from {img.size} to ({target_width}, {target_height})")
        img = img.resize((target_width, target_height), Image.Resampling.LANCZOS)

    pixels = list(img.getdata()) # pixels เป็น list ของ tuple (R, G, B)

    # --- START OF CORRECTION ---
    with open(output_hex_path, 'w') as f:
        # pixel คือ tuple เช่น (255, 0, 128)
        for pixel in pixels:
            r, g, b = pixel
            # รวมค่า R, G, B เป็นเลขฐานสิบหก 6 หลัก (24-bit) ในบรรทัดเดียว
            # f-string จะจัดรูปแบบให้ r, g, b เป็นเลขฐานสิบหก 2 หลัก (02x)
            # แล้วนำมาต่อกัน ก่อนที่จะขึ้นบรรทัดใหม่
            f.write(f"{r:02x}{g:02x}{b:02x}\n")
    # --- END OF CORRECTION ---

    print(f"Successfully preprocessed '{input_bmp_path}' ({img.width}x{img.height}) to '{output_hex_path}' with 24-bit RGB hex data.")

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python preprocess_rgb_to_24bit_hex.py <input_bmp_file> <output_hex_file> <width> <height>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    width = int(sys.argv[3])
    height = int(sys.argv[4])
    preprocess_bmp_rgb_to_24bit_hex(input_file, output_file, width, height)