from pathlib import Path
import sys

root = Path(sys.argv[1])
build_id = sys.argv[2][:8]

renames = {
    "index.js": f"game-{build_id}.js",
    "index.wasm": f"game-{build_id}.wasm",
    "index.pck": f"game-{build_id}.pck",
    "index.audio.worklet.js": f"game-{build_id}.audio.worklet.js",
}

for old_name, new_name in renames.items():
    old_path = root / old_name
    if old_path.exists():
        old_path.rename(root / new_name)

index = root / "index.html"
html = index.read_text(encoding="utf-8")
html = html.replace('index.js', f'game-{build_id}.js')
html = html.replace('"executable":"index"', f'"executable":"game-{build_id}"')
html = html.replace('index.pck', f'game-{build_id}.pck')
html = html.replace('index.wasm', f'game-{build_id}.wasm')

cache_meta = (
    '<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">\n'
    '<meta http-equiv="Pragma" content="no-cache">\n'
    '<meta http-equiv="Expires" content="0">\n'
    f'<meta name="pirate-build" content="{build_id}">'
)
html = html.replace("<head>", "<head>\n" + cache_meta, 1)
index.write_text(html, encoding="utf-8")

print(f"Prepared web preview build {build_id}")
