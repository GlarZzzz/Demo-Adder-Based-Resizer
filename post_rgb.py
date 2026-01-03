from PIL import Image
import numpy as np
import os

# --- THIS IS THE CORRECT FUNCTION FOR YOUR LATEST VERILOG OUTPUT ---
def txt_24bit_to_bmp(txt_input_path, bmp_output_path, dst_width, dst_height):
    """
    Reads a text file containing 24-bit hexadecimal pixel values (RRGGBB, one
    pixel per line), parses them into R, G, B components, reshapes the data
    into an RGB image array, and saves it as a BMP file.
    """
    try:
        if not os.path.exists(txt_input_path):
            print(f"Error: Input text file '{txt_input_path}' not found.")
            return False

        # This list will hold the individual 8-bit R, G, B components
        component_values = []
        
        with open(txt_input_path, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line_stripped = line.strip()
                if not line_stripped:
                    continue
                try:
                    # --- THE KEY OPERATION: PARSING THE 24-BIT VALUE ---
                    # Read the full 24-bit hex value from the line
                    pixel_24bit = int(line_stripped, 16) # base 16 for hex
                    
                    # Extract R, G, B components using bit-shifting and masking
                    r_val = (pixel_24bit >> 16) & 0xFF
                    g_val = (pixel_24bit >> 8) & 0xFF
                    b_val =  pixel_24bit & 0xFF
                    
                    # Append components in R, G, B order
                    component_values.append(r_val)
                    component_values.append(g_val)
                    component_values.append(b_val)
                    
                except ValueError:
                    print(f"Warning: Skipping non-hex or malformed value at line {line_num}: '{line_stripped}'")
                    continue
        
        print(f"Read {len(component_values)//3} pixels from {txt_input_path}")

        expected_pixels = dst_width * dst_height
        if (len(component_values) // 3) != expected_pixels:
            print(f"Error: Expected {expected_pixels} pixels for image size {dst_width}x{dst_height}, but got {len(component_values)//3}.")
            # In case of mismatch, you can choose to pad or truncate if needed for debugging.
            # For this final script, we will return an error to ensure correctness.
            return False

        # Reshape the list of components into the image array
        img_array = np.array(component_values, dtype=np.uint8).reshape((dst_height, dst_width, 3))

        img = Image.fromarray(img_array, mode='RGB')
        print(f"Created RGB image of size ({dst_width}x{dst_height}).")
        
        img.save(bmp_output_path)
        print(f"Output RGB image saved to {bmp_output_path}")
        return True

    except Exception as e:
        print(f"An unexpected error occurred during post-processing: {e}")
        return False

# You can keep the old function for reference if you want
def txt_to_bmp_rgb_sequential(txt_input_path, bmp_output_path, dst_width, dst_height):
    # This is your original function that reads 8-bit components per line.
    # It won't work with the latest Verilog output but is kept here.
    try:
        # (Function body is the same as your original)
        pass # To avoid syntax error
    except Exception as e:
        pass


if __name__ == "__main__":
    # --- Configuration (MUST match your Verilog DST_WIDTH, DST_HEIGHT parameters) ---
    VERILOG_DST_WIDTH = 640
    VERILOG_DST_HEIGHT = 480

    input_txt_from_verilog = "verilog_output_pixels.txt"
    output_bmp_file = "output_resized_image.bmp"

    print("--- Starting Post-processing (24-bit/pixel mode) ---")
    if txt_24bit_to_bmp(input_txt_from_verilog, output_bmp_file, VERILOG_DST_WIDTH, VERILOG_DST_HEIGHT):
        print("\nPost-processing successful!")
        print(f"You can now view the final resized image at '{output_bmp_file}'.")
    else:
        print("\nPost-processing failed. Please review error messages and check input/Verilog output.")
    print("--------------------------------------------------")
