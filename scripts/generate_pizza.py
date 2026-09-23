"""Generate Vouchhunter's original low-poly pizza GLB. No external assets."""
import json, math, struct
from pathlib import Path
binary=bytearray();views=[];accessors=[];meshes=[];nodes=[]
materials=[{'name':'Baked crust','pbrMetallicRoughness':{'baseColorFactor':[.82,.48,.16,1],'metallicFactor':0,'roughnessFactor':.85}}, {'name':'Cheese','pbrMetallicRoughness':{'baseColorFactor':[1,.75,.20,1],'metallicFactor':0,'roughnessFactor':.7}}, {'name':'Tomato','pbrMetallicRoughness':{'baseColorFactor':[.72,.12,.06,1],'metallicFactor':0,'roughnessFactor':.8}}]
def floats(values,kind,count):
 start=len(binary);flat=[x for row in values for x in row];binary.extend(struct.pack('<'+'f'*len(flat),*flat));views.append({'buffer':0,'byteOffset':start,'byteLength':len(flat)*4})
 a={'bufferView':len(views)-1,'componentType':5126,'count':count,'type':kind}
 if kind=='VEC3':a.update(min=[min(row[i] for row in values)for i in range(3)],max=[max(row[i] for row in values)for i in range(3)])
 accessors.append(a);return len(accessors)-1
def cylinder(radius,height,material,center):
 vertices=[];normals=[]
 def triangle(points,ns):vertices.extend(points);normals.extend(ns)
 for i in range(40):
  a=i*math.tau/40;b=(i+1)*math.tau/40
  p=[(radius*math.cos(t),y,radius*math.sin(t))for y,t in [(0,a),(0,b),(height,a),(height,b)]]
  na=(math.cos(a),0,math.sin(a));nb=(math.cos(b),0,math.sin(b))
  triangle([p[0],p[2],p[1]],[na,na,nb]);triangle([p[1],p[2],p[3]],[nb,na,nb])
  triangle([(0,height,0),p[3],p[2]],[(0,1,0)]*3);triangle([(0,0,0),p[0],p[1]],[(0,-1,0)]*3)
 positions=floats(vertices,'VEC3',len(vertices));normal=floats(normals,'VEC3',len(normals))
 meshes.append({'primitives':[{'attributes':{'POSITION':positions,'NORMAL':normal},'material':material}]});nodes.append({'mesh':len(meshes)-1,'translation':list(center)})
cylinder(.72,.10,0,(0,.65,0));cylinder(.65,.025,1,(0,.75,0))
for i in range(9):
 a=i*math.tau/9;cylinder(.085,.016,2,(.43*math.cos(a),.775,.43*math.sin(a)))
cylinder(.10,.016,2,(0,.775,0))
doc={'asset':{'version':'2.0','generator':'Vouchhunter original mesh generator'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],'nodes':nodes,'meshes':meshes,'materials':materials,'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors}
raw=json.dumps(doc,separators=(',',':')).encode();raw+=b' '*((-len(raw))%4)
out=struct.pack('<III',0x46546c67,2,12+8+len(raw)+8+len(binary))+struct.pack('<II',len(raw),0x4e4f534a)+raw+struct.pack('<II',len(binary),0x004e4942)+binary
path=Path(__file__).resolve().parents[1]/'android/app/src/main/assets/models/pizza.glb'
path.write_bytes(out);print(f'Generated {path.name}: {len(out)} bytes, {len(meshes)} meshes')
