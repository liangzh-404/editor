#!/usr/bin/env bash
set -euo pipefail

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' is required to generate app icons." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asset_root="$repo_root/Sources/EditorApp/Assets.xcassets"
iconset="$asset_root/AppIcon.appiconset"
light_master="$iconset/AppIcon-iOS-Light-1024.png"
dark_master="$iconset/AppIcon-iOS-Dark-1024.png"

if [[ ! -f "$light_master" || ! -f "$dark_master" ]]; then
  echo "Missing ImageGen master icons:" >&2
  echo "  $light_master" >&2
  echo "  $dark_master" >&2
  exit 1
fi

mkdir -p "$iconset"
find "$iconset" -type f -name 'AppIcon-Mac-Light-*.png' -delete

cat > "$asset_root/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

render_icon() {
  local source_png="$1"
  local output_png="$2"
  local pixels="$3"

  magick "$source_png" \
    -resize "${pixels}x${pixels}!" \
    -alpha remove \
    -alpha off \
    -strip \
    "$output_png"
}

render_icon "$light_master" "$light_master" 1024
render_icon "$dark_master" "$dark_master" 1024

mac_entries=(
  "16x16 1x 16"
  "16x16 2x 32"
  "32x32 1x 32"
  "32x32 2x 64"
  "128x128 1x 128"
  "128x128 2x 256"
  "256x256 1x 256"
  "256x256 2x 512"
  "512x512 1x 512"
  "512x512 2x 1024"
)

for entry in "${mac_entries[@]}"; do
  read -r point_size scale pixels <<<"$entry"
  render_icon "$light_master" "$iconset/AppIcon-Mac-Light-${point_size}@${scale}.png" "$pixels"
done

cat > "$iconset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon-iOS-Light-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-iOS-Dark-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "AppIcon-Mac-Light-16x16@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "AppIcon-Mac-Light-16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "AppIcon-Mac-Light-32x32@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "AppIcon-Mac-Light-32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "AppIcon-Mac-Light-128x128@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "AppIcon-Mac-Light-128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "AppIcon-Mac-Light-256x256@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "AppIcon-Mac-Light-256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "AppIcon-Mac-Light-512x512@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "AppIcon-Mac-Light-512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Generated app icons in $iconset"
