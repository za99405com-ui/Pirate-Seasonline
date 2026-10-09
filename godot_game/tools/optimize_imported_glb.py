#!/usr/bin/env python3
"""Lossy texture compression of generated GLBs, preserving vertex/index geometry."""
import argparse
import io
import json
import struct
from pathlib import Path
from PIL import Image

CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942

def aligned(raw, pad=b'\0'):
    return raw + pad * ((-len(raw)) % 4)

def optimize(src, dest, max_px=1536):
    raw=Path(src).read_bytes()
    magic,version,length=struct.unpack_from('<4sII',raw,0)
    if magic != b'glTF' or version != 2 or len(raw)!=length: raise ValueError('Invalid GLB2')
    offset=12
    parts={}
    while offset<len(raw):
        count,kind=struct.unpack_from('<II',raw,offset);offset+=8
        parts[kind]=raw[offset:offset+count];offset+=count
    gltf=json.loads(parts[CHUNK_JSON]);oldbin=parts[CHUNK_BIN]
    views=gltf['bufferViews'];replacement={}
    for idx,img in enumerate(gltf.get('images',[])):
        if 'bufferView' not in img:continue
        view_id=img['bufferView'];v=views[view_id];start=v.get('byteOffset',0)
        source=oldbin[start:start+v['byteLength']]
        picture=Image.open(io.BytesIO(source))
        picture.thumbnail((max_px,max_px),Image.Resampling.LANCZOS)
        has_alpha='A' in picture.getbands() and picture.getchannel('A').getextrema()[0]<255
        stream=io.BytesIO()
        if has_alpha:
            picture.convert('RGBA').save(stream,format='PNG',optimize=True)
            img['mimeType']='image/png'
        else:
            picture.convert('RGB').save(stream,format='JPEG',quality=83,subsampling=0,optimize=True)
            img['mimeType']='image/jpeg'
        replacement[view_id]=stream.getvalue()
    newbin=bytearray()
    for i,v in enumerate(views):
        start=v.get('byteOffset',0)
        data=replacement.get(i)
        if data is None:data=oldbin[start:start+v['byteLength']]
        newbin.extend(bytes((-len(newbin))%4))
        v['byteOffset']=len(newbin)
        v['byteLength']=len(data)
        newbin.extend(data)
    newbin.extend(bytes((-len(newbin))%4))
    gltf['buffers'][0]['byteLength']=len(newbin)
    j=aligned(json.dumps(gltf,ensure_ascii=False,separators=(',',':')).encode(),b' ')
    overall=12+8+len(j)+8+len(newbin)
    dest=Path(dest);dest.parent.mkdir(parents=True,exist_ok=True)
    with dest.open('wb') as f:
        f.write(struct.pack('<4sII',b'glTF',2,overall))
        f.write(struct.pack('<II',len(j),CHUNK_JSON));f.write(j)
        f.write(struct.pack('<II',len(newbin),CHUNK_BIN));f.write(newbin)
    print(f'{src} -> {dest}: {len(raw):,} -> {overall:,} bytes ({len(replacement)} images)')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('target');p.add_argument('--max-texture',type=int,default=1536)
    args=p.parse_args();optimize(args.source,args.target,args.max_texture)
