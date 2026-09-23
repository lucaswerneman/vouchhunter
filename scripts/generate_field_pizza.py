"""Create an original self-contained USDZ pizza for the explicitly labelled field test.
No downloaded geometry, texture references, or external USD dependencies.
"""

import math
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parts = []


def disc(name, radius, height, color, center=(0, 0, 0), segments=48):
    vertices = []

    def point(angle, y):
        return (
            center[0] + radius * math.cos(angle),
            center[1] + y,
            center[2] + radius * math.sin(angle),
        )

    for i in range(segments):
        a, b = i * 2 * math.pi / segments, (i + 1) * 2 * math.pi / segments
        top, bottom = (center[0], center[1] + height / 2, center[2]), (
            center[0],
            center[1] - height / 2,
            center[2],
        )
        vertices.extend(
            [
                top,
                point(b, height / 2),
                point(a, height / 2),
                bottom,
                point(a, -height / 2),
                point(b, -height / 2),
                point(a, -height / 2),
                point(a, height / 2),
                point(b, height / 2),
                point(a, -height / 2),
                point(b, height / 2),
                point(b, -height / 2),
            ]
        )
    points = ", ".join("(%s)" % ", ".join(f"{n:.6f}" for n in v) for v in vertices)
    parts.append(
        f"""def Mesh "{name}" (prepend apiSchemas = ["MaterialBindingAPI"]) {{
        uniform token subdivisionScheme = "none"
        bool doubleSided = true
        point3f[] points = [{points}]
        int[] faceVertexCounts = [{', '.join(['3']*(len(vertices)//3))}]
        int[] faceVertexIndices = [{', '.join(map(str,range(len(vertices))))}]
        rel material:binding = </Pizza/{name}Material>
    }}
    def Material "{name}Material" {{
        token outputs:surface.connect = </Pizza/{name}Material/Shader.outputs:surface>
        def Shader "Shader" {{
            uniform token info:id = "UsdPreviewSurface"
            color3f inputs:diffuseColor = ({', '.join(map(str,color))})
            float inputs:roughness = 0.8
            float inputs:metallic = 0
            token outputs:surface
        }}
    }}"""
    )


disc("Crust", 0.70, 0.12, (0.68, 0.32, 0.08))
disc("Tomato", 0.625, 0.018, (0.62, 0.05, 0.015), (0, 0.067, 0))
disc("Cheese", 0.605, 0.024, (1.0, 0.71, 0.19), (0, 0.084, 0))
for i in range(7):
    angle = i * 2 * math.pi / 7
    disc(
        f"Pepperoni{i}",
        0.088,
        0.014,
        (0.68, 0.065, 0.025),
        (0.37 * math.cos(angle), 0.103, 0.37 * math.sin(angle)),
        20,
    )
disc("PepperoniCenter", 0.095, 0.014, (0.68, 0.065, 0.025), (0, 0.103, 0), 20)
source = (
    '#usda 1.0\n( defaultPrim = "Pizza"\n metersPerUnit = 1\n upAxis = "Y" )\ndef Xform "Pizza" {\n'
    + "\n".join(parts)
    + "\n}\n"
)
output = ROOT / "ios/Vouchhunter/Resources/brillo-pizza.usdz"
output.parent.mkdir(parents=True, exist_ok=True)
info = zipfile.ZipInfo("pizza.usda")
info.compress_type = zipfile.ZIP_STORED
# USDZ mandates each embedded file payload starts on a 64-byte boundary.
padding = (-(30 + len(info.filename.encode()) + 4)) % 64
info.extra = struct.pack("<HH", 0x1986, padding) + bytes(padding)
with zipfile.ZipFile(output, "w") as archive:
    archive.writestr(info, source.encode())
with zipfile.ZipFile(output) as archive:
    entry = archive.infolist()[0]
    assert (
        entry.header_offset + 30 + len(entry.filename.encode()) + len(entry.extra)
    ) % 64 == 0
    assert archive.testzip() is None
print(f"Created {output.name}: {output.stat().st_size} bytes")
