"""Validate self-contained 3D uploads; never extract an archive on the server."""

import io
import json
import struct
import zipfile
from pathlib import PurePosixPath


def validate_model(raw, kind):
    if not 20 <= len(raw) <= 12 * 1024 * 1024:
        raise ValueError("Modellen måste vara mellan 20 byte och 12 MB.")
    if kind == "glb":
        magic, version, length = struct.unpack_from("<III", raw)
        if magic != 0x46546C67 or version != 2 or length != len(raw):
            raise ValueError("Filen är inte en giltig GLB 2.0-modell.")
        offset = 12
        document = None
        binary_length = 0
        while offset < len(raw):
            if offset + 8 > len(raw):
                raise ValueError("Skadad GLB-fil.")
            size, chunk = struct.unpack_from("<II", raw, offset)
            offset += 8
            if size % 4 or offset + size > len(raw):
                raise ValueError("Skadad GLB-fil.")
            if document is None:
                if chunk != 0x4E4F534A:
                    raise ValueError("GLB saknar JSON-header.")
                document = json.loads(raw[offset : offset + size])
            elif chunk == 0x004E4942:
                binary_length += size
            offset += size
        if (
            not isinstance(document, dict)
            or document.get("asset", {}).get("version") != "2.0"
        ):
            raise ValueError("GLB-versionen stöds inte.")
        for resource in document.get("buffers", []) + document.get("images", []):
            if "uri" in resource:
                raise ValueError(
                    "Alla texturer och buffertar måste vara inbäddade i GLB-filen."
                )
        if any(
            b.get("byteLength", 0) > binary_length for b in document.get("buffers", [])
        ):
            raise ValueError("GLB-bufferten är ofullständig.")
        return
    if kind == "usdz":
        try:
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                entries = archive.infolist()
                if (
                    not entries
                    or len(entries) > 250
                    or sum(e.file_size for e in entries) > 64 * 1024 * 1024
                ):
                    raise ValueError("USDZ-arkivet är för stort.")
                allowed = {
                    ".usd",
                    ".usda",
                    ".usdc",
                    ".png",
                    ".jpg",
                    ".jpeg",
                    ".exr",
                    ".avif",
                }
                for e in entries:
                    path = PurePosixPath(e.filename)
                    if (
                        path.is_absolute()
                        or ".." in path.parts
                        or "\\" in e.filename
                        or e.flag_bits & 1
                        or (e.external_attr >> 16) & 0o170000 == 0o120000
                    ):
                        raise ValueError("Otillåten filsökväg i USDZ.")
                    if not e.is_dir() and path.suffix.lower() not in allowed:
                        raise ValueError("Otillåten filtyp i USDZ.")
                    if e.compress_type != zipfile.ZIP_STORED:
                        raise ValueError("USDZ ska vara ett okomprimerat arkiv.")
                if not any(
                    PurePosixPath(e.filename).suffix.lower()
                    in {".usd", ".usda", ".usdc"}
                    for e in entries
                ):
                    raise ValueError("USDZ saknar USD-scen.")
                if archive.testzip() is not None:
                    raise ValueError("USDZ-filen är skadad.")
        except zipfile.BadZipFile:
            raise ValueError("Filen är inte ett giltigt USDZ-arkiv.")
        return
    raise ValueError("Använd GLB för Android eller USDZ för iPhone.")
