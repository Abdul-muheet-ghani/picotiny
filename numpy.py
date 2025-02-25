from PIL import Image

# Input and Output Paths
input_image_path = "im.png"  # Replace with your image path
output_file_path = "output_pixels.txt"  # File to save pixel data

# Open the image
image = Image.open(input_image_path)

# Convert the image to RGB (if not already in RGB format)
image = image.convert("RGB")

# Get the dimensions of the image
width, height = image.size

# Extract and save RGB pixel data
with open(output_file_path, "w") as output_file:
    for y in range(height):
        for x in range(width):
            # Get the RGB values of the pixel
            r, g, b = image.getpixel((x, y))
            # Write pixel values to file
            #output_file.write(f"{hex(r)[2:3]}\n")
            #output_file.write(f"({hex(r)[2:3]}, {hex(g)[2:3]}, {hex(b)[2:3]})\n")
            # Example for extracting 6-bit value and writing it
            # Write the 6-bit value in binary format
            output_file.write(f"{((r >> 7) & 0b1) << 4 | ((g >> 6) & 0b11) << 2 | ((b >> 6) & 0b11):05b}\n")




print(f"RGB pixel data has been saved to {output_file_path}.")