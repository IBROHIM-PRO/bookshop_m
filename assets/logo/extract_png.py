import re
import base64

svg_path = "/home/ibrohim/document/bookshop/logo/logoteaherfutter/image 83.svg"
png_path = "/home/ibrohim/document/bookshop/bookshop_m/assets/logo/teacher_grading.png"

with open(svg_path, "r") as f:
    content = f.read()

# Find the base64 data
match = re.search(r'xlink:href="data:image/png;base64,([^"]+)"', content)
if match:
    base64_data = match.group(1)
    # Decode and write to PNG
    with open(png_path, "wb") as f_out:
        f_out.write(base64.b64decode(base64_data))
    print("Successfully extracted base64 PNG to png file!")
else:
    print("Could not find base64 data in SVG!")
