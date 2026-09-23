"""Bounded campaign appearance. No executable CSS, HTML, or credential-bearing URLs."""

import ipaddress
import re
from urllib.parse import urlsplit


def validate_branding(data):
    if not isinstance(data, dict) or set(data) - {
        "accent_color",
        "background_color",
        "logo_url",
        "hero_url",
    }:
        raise ValueError("Ogiltiga varumärkesfält.")
    result = {}
    for key, fallback in [("accent_color", "#242424"), ("background_color", "#F5F5F5")]:
        value = data.get(key, fallback)
        if not isinstance(value, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            raise ValueError("Ange en färg med sex hexadecimala tecken.")
        result[key] = value.upper()
    for key in ["logo_url", "hero_url"]:
        value = data.get(key, "")
        if not isinstance(value, str) or len(value) > 2048:
            raise ValueError("Bildadressen är för lång.")
        value = value.strip()
        if value:
            parsed = urlsplit(value)
            host = parsed.hostname or ""
            if (
                parsed.scheme != "https"
                or not host
                or parsed.username
                or parsed.password
                or parsed.fragment
                or any(c.isspace() for c in value)
            ):
                raise ValueError(
                    "Bilder måste ha en offentlig HTTPS-adress utan inloggningsuppgifter."
                )
            if host.lower() == "localhost" or host.lower().endswith(
                (".localhost", ".local", ".internal")
            ):
                raise ValueError("Lokala bildadresser är inte tillåtna.")
            try:
                address = ipaddress.ip_address(host)
            except ValueError:
                if "." not in host:
                    raise ValueError("Ange en offentlig bildadress.")
            else:
                if not address.is_global:
                    raise ValueError("Privata bildadresser är inte tillåtna.")
        result[key] = value
    return result
