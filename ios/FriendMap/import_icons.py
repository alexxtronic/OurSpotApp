import os
import shutil
import json

source_dir = "/Users/alexdamore/Desktop/Vibe_Code/Antigravity/Antigravity - Dec 11 2025 - Testing/friendmap/ios/FriendMap/new icons/realistic"
dest_root = "/Users/alexdamore/Desktop/Vibe_Code/Antigravity/Antigravity - Dec 11 2025 - Testing/friendmap/ios/FriendMap/Assets.xcassets/ActivityIcons"

# Ensure destination root exists
os.makedirs(dest_root, exist_ok=True)

# Contents.json template for a single scale image (vectors or generic scale)
# Since these are PNGs and we want them to be scalable or just used as 1x/2x/3x, 
# for simplicity and because they are high res, we can set them as "universal" "single-scale" or "1x"
# But usually for a single PNG we treat it as 1x or "universal". 
# Let's use "universal" at scale "1x" if the resolution is high, or just let Xcode handle it.
# A safe single-image config:
def get_contents_json(filename):
    return {
      "images" : [
        {
          "filename" : filename,
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "idiom" : "universal",
          "scale" : "3x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

# Actually, if we only have one file, we should probably set it as 1x 2x 3x or just 1x?
# If we only provide one file, validation warns if others are missing.
# Let's try to just provide one "universal" image with no specific scale, or just fill 1x.
# Better strategy: Set it as "single-scale" if we want it to just scale?
# Or clearer: Just Put it in 1x slot. Or simpler: "scale": "1x"

def get_simple_contents_json(filename):
    return {
      "images" : [
        {
          "filename" : filename,
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
# Note: "idiom": "universal" without scale usually implies it covers everything or is a vector. 
# For PNGs Xcode might want specific scales. 
# Let's use the simple one and if Xcode complains we fix it. 
# Actually, the "universal" idiom without scale defaults to 1x? 
# Let's use the format where we specify 'scale' for the item.

def get_single_scale_contents_json(filename):
    return {
      "images" : [
        {
          "filename" : filename,
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "idiom" : "universal",
          "scale" : "3x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    
# Wait, if I don't have 2x and 3x files, I shouldn't list them.
# I'll just list the 1x.
def get_1x_contents_json(filename):
    return {
      "images" : [
        {
          "filename" : filename,
          "idiom" : "universal",
          "scale" : "1x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

files = [f for f in os.listdir(source_dir) if f.endswith(".png")]

for f in files:
    name_no_ext = os.path.splitext(f)[0]
    
    # Check for gaming removal just in case
    if name_no_ext == "gaming":
        continue
        
    imageset_dir = os.path.join(dest_root, f"{name_no_ext}.imageset")
    os.makedirs(imageset_dir, exist_ok=True)
    
    # Copy file
    shutil.copy(os.path.join(source_dir, f), os.path.join(imageset_dir, f))
    
    # Write Contents.json
    with open(os.path.join(imageset_dir, "Contents.json"), "w") as json_file:
        json.dump(get_1x_contents_json(f), json_file, indent=2)

print(f"Processed {len(files)} icons.")
