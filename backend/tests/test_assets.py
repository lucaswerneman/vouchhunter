import io
import json
import struct
import unittest
import zipfile
from backend.assets import validate_model

def glb(document):
    data=json.dumps(document).encode();data+=b' '*((-len(data))%4)
    return struct.pack('<III',0x46546c67,2,20+len(data))+struct.pack('<II',len(data),0x4e4f534a)+data

def usdz(name,body):
    output=io.BytesIO()
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_STORED) as archive:archive.writestr(name,body)
    return output.getvalue()

class AssetValidationTests(unittest.TestCase):
    def test_accepts_self_contained_glb(self):validate_model(glb({'asset':{'version':'2.0'}}),'glb')
    def test_rejects_glb_external_texture(self):
        with self.assertRaises(ValueError):validate_model(glb({'asset':{'version':'2.0'},'images':[{'uri':'https://tracker.example/texture.png'}]}),'glb')
    def test_rejects_truncated_glb(self):
        with self.assertRaises(ValueError):validate_model(glb({'asset':{'version':'2.0'}})[:-4],'glb')
    def test_rejects_archive_traversal(self):
        with self.assertRaises(ValueError):validate_model(usdz('../scene.usda','#usda 1.0'),'usdz')
    def test_rejects_executable_in_archive(self):
        with self.assertRaises(ValueError):validate_model(usdz('run.sh','echo hello'),'usdz')
    def test_accepts_uncompressed_usd_scene(self):validate_model(usdz('scene.usda','#usda 1.0'),'usdz')
    def test_rejects_arbitrary_format(self):
        with self.assertRaises(ValueError):validate_model(b'X'*30,'html')
