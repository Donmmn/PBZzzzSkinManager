"""Offline public-source checks; does not launch or modify the game."""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--core-zip', type=Path, required=True)
parser.add_argument('--lua', action='store_true', help='Compile Lua through optional lupa')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
lua = None
if args.lua:
    from lupa import LuaRuntime
    lua = LuaRuntime().eval('function(s,n) local f,e=load(s,n); assert(f,e) end')
with zipfile.ZipFile(args.core_zip) as z:
    assert z.testzip() is None, 'Core ZIP integrity failed'
    for p in sorted((root / 'Scripts').glob('*.lua')):
        member = 'GameFiles/platform/steam/ue4ss/Mods/PBZWardrobe/Scripts/' + p.name
        assert p.read_bytes() == z.read(member), 'Runtime source mismatch: ' + p.name
        if lua:
            lua(p.read_text(encoding='utf-8-sig'), p.name)
for p in (root / 'schema').glob('*.json'):
    json.loads(p.read_text(encoding='utf-8-sig'))
for p in root.rglob('*'):
    if not p.is_file() or '.git' in p.parts:
        continue
    assert p.suffix.lower() not in {'.exe', '.dll', '.pak', '.utoc', '.ucas', '.mp4', '.dmp', '.log', '.zip'}, p
    assert p.name != 'selected.txt' and 'State' not in p.relative_to(root).parts, p
    if p.suffix.lower() in {'.lua', '.json', '.cpp', '.cmd', '.py', '.hlsl', '.md', '.txt'}:
        text = p.read_text(encoding='utf-8-sig')
        for forbidden in ('C:' + chr(92) + 'Users' + chr(92) + '33839', '.'.join(('192','168','1','156')), 'BILI' + '_COOKIES', 'G:' + chr(92) + 'SteamLibrary'):
            assert forbidden not in text, (p, forbidden)
print(json.dumps({'status': 'pass', 'runtime_lua_files': len(list((root / 'Scripts').glob('*.lua'))), 'lua_compilation': bool(lua), 'core_sha256': hashlib.sha256(args.core_zip.read_bytes()).hexdigest(), 'in_game_acceptance': 'not performed by this offline check'}, indent=2))
