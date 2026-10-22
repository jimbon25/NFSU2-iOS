#!/usr/bin/env python3
"""
Fetch SPEED2.EXE and server.dll from Archive.org via HTTP Range Requests.
Downloads only ~2.4 MB instead of the entire 2.5 GB archive.
"""

import hashlib
import os
import struct
import sys
import urllib.request
import zlib

ARCHIVE_URL = "https://archive.org/download/nfsu-2_202509/NFSU2.zip"
TOTAL_ZIP_SIZE = 2593450931
EXPECTED_SHA256 = "f9dd86c054878ce6276beb07c1fd61874f7a1e4bf1f241b084c65b73e24168a7"

TARGETS = {
    "NFSU2/SPEED2.EXE": {"offset": 2428003821, "csz": 2240852, "out": "SPEED2.EXE"},
    "NFSU2/server.dll": {"offset": 2292289747, "csz": 152756, "out": "server.dll"},
}


def fetch_file(url, offset, csz, out_name):
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    req = urllib.request.Request(
        url, headers={**headers, "Range": f"bytes={offset}-{offset + csz + 2048}"}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()

    (
        magic,
        ver,
        flags,
        method,
        time,
        date,
        crc,
        c_csz,
        usz,
        fn_len,
        extra_len,
    ) = struct.unpack("<IHHHHHIIIHH", data[:30])

    raw_comp = data[30 + fn_len + extra_len : 30 + fn_len + extra_len + c_csz]
    decomp = zlib.decompress(raw_comp, -15) if method == 8 else raw_comp

    with open(out_name, "wb") as f:
        f.write(decomp)
    return decomp


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out_dir, exist_ok=True)

    for zip_path, meta in TARGETS.items():
        out_path = os.path.join(out_dir, meta["out"])
        print(f"Fetching {zip_path} -> {out_path}...")
        decomp = fetch_file(ARCHIVE_URL, meta["offset"], meta["csz"], out_path)
        sha256 = hashlib.sha256(decomp).hexdigest()
        print(f"  Extracted {len(decomp)} bytes, SHA-256: {sha256}")

        if meta["out"] == "SPEED2.EXE":
            if sha256 != EXPECTED_SHA256:
                print(f"ERROR: SHA-256 mismatch! Expected {EXPECTED_SHA256}")
                sys.exit(1)
            print("  Checksum verified successfully!")

    print("All files ready.")


if __name__ == "__main__":
    main()
