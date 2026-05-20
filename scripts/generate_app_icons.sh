#!/usr/bin/env bash
set -euo pipefail

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' is required to generate app icons." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asset_root="$repo_root/Sources/EditorApp/Assets.xcassets"
iconset="$asset_root/AppIcon.appiconset"
tmp_dir="$(mktemp -d)"

trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$iconset"
find "$iconset" -type f -name '*.png' -delete

cat > "$asset_root/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cat > "$tmp_dir/editor-icon-light.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#F7F2E9"/>
  <rect x="208" y="156" width="648" height="752" rx="98" fill="#D5C6B1" opacity="0.24"/>
  <rect x="176" y="120" width="648" height="752" rx="98" fill="#FFFDF7"/>
  <path d="M708 120h50c54 0 98 44 98 98v54L708 120Z" fill="#EEE4D4"/>
  <path d="M708 120v108c0 24 20 44 44 44h104L708 120Z" fill="#F8F2E8"/>
  <rect x="250" y="236" width="42" height="482" rx="21" fill="#E5454F"/>
  <path d="M356 314h292" stroke="#27272A" stroke-width="28" stroke-linecap="round" opacity="0.86"/>
  <path d="M356 422h354" stroke="#27272A" stroke-width="28" stroke-linecap="round" opacity="0.62"/>
  <path d="M356 530h288" stroke="#27272A" stroke-width="28" stroke-linecap="round" opacity="0.44"/>
  <path d="M356 638h210" stroke="#27272A" stroke-width="28" stroke-linecap="round" opacity="0.30"/>
  <g transform="rotate(-35 666 708)">
    <rect x="506" y="672" width="306" height="78" rx="39" fill="#E5454F"/>
    <rect x="562" y="690" width="180" height="16" rx="8" fill="#FF8B92" opacity="0.76"/>
    <path d="M808 672 884 711 808 750Z" fill="#242429"/>
    <path d="M856 697 884 711 856 725Z" fill="#FFFDF7"/>
  </g>
</svg>
SVG

cat > "$tmp_dir/editor-icon-dark.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#111318"/>
  <rect x="208" y="156" width="648" height="752" rx="98" fill="#000000" opacity="0.28"/>
  <rect x="176" y="120" width="648" height="752" rx="98" fill="#23262D"/>
  <path d="M708 120h50c54 0 98 44 98 98v54L708 120Z" fill="#393D47"/>
  <path d="M708 120v108c0 24 20 44 44 44h104L708 120Z" fill="#2C3038"/>
  <rect x="250" y="236" width="42" height="482" rx="21" fill="#FF5964"/>
  <path d="M356 314h292" stroke="#F7EFE3" stroke-width="28" stroke-linecap="round" opacity="0.88"/>
  <path d="M356 422h354" stroke="#F7EFE3" stroke-width="28" stroke-linecap="round" opacity="0.64"/>
  <path d="M356 530h288" stroke="#F7EFE3" stroke-width="28" stroke-linecap="round" opacity="0.46"/>
  <path d="M356 638h210" stroke="#F7EFE3" stroke-width="28" stroke-linecap="round" opacity="0.32"/>
  <g transform="rotate(-35 666 708)">
    <rect x="506" y="672" width="306" height="78" rx="39" fill="#FF5964"/>
    <rect x="562" y="690" width="180" height="16" rx="8" fill="#FFC0C4" opacity="0.62"/>
    <path d="M808 672 884 711 808 750Z" fill="#F7EFE3"/>
    <path d="M856 697 884 711 856 725Z" fill="#111318"/>
  </g>
</svg>
SVG

render_icon() {
  local source_svg="$1"
  local output_png="$2"
  local pixels="$3"

  magick -density 512 "$source_svg" \
    -resize "${pixels}x${pixels}" \
    -background none \
    -alpha remove \
    -alpha off \
    -strip \
    "$output_png"
}

render_icon "$tmp_dir/editor-icon-light.svg" "$iconset/AppIcon-iOS-Light-1024.png" 1024
render_icon "$tmp_dir/editor-icon-dark.svg" "$iconset/AppIcon-iOS-Dark-1024.png" 1024

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
  render_icon "$tmp_dir/editor-icon-light.svg" "$iconset/AppIcon-Mac-Light-${point_size}@${scale}.png" "$pixels"
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
