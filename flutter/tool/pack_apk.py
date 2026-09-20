#!/usr/bin/env python3
"""Stitch a valid release APK from AGP 9 intermediates, then align and sign it."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


def flutter_root() -> Path:
    return Path(__file__).resolve().parent.parent


def android_sdk() -> Path:
    for key in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        value = os.environ.get(key)
        if value:
            return Path(value)
    local = flutter_root() / "android" / "local.properties"
    if local.exists():
        for line in local.read_text().splitlines():
            if line.startswith("sdk.dir="):
                return Path(line.split("=", 1)[1].strip().replace("\\", "/"))
    return Path("/home/iraqies/sdk/android-sdk")


def newest(path: Path, pattern: str) -> Path | None:
    matches = sorted(path.glob(pattern), key=lambda p: p.stat().st_mtime, reverse=True)
    return matches[0] if matches else None


def build_tools() -> Path:
    root = android_sdk() / "build-tools"
    versions = sorted((p for p in root.iterdir() if p.is_dir()), reverse=True)
    if not versions:
        raise SystemExit(f"No Android build-tools in {root}")
    return versions[0]


def find_ap_(app_build: Path) -> Path:
    for pattern in (
        "intermediates/linked_resources_binary_format/**/*.ap_",
        "intermediates/linked_resources_proto_format/**/*.ap_",
        "intermediates/**/*release*.ap_",
        "intermediates/**/*.ap_",
    ):
        found = newest(app_build, pattern)
        if found:
            return found
    raise SystemExit("Could not find linked resources .ap_")


def find_dex(app_build: Path) -> list[Path]:
    for pattern in (
        "intermediates/dex/release/minifyReleaseWithR8/*.dex",
        "intermediates/dex/release/mergeDexRelease/*.dex",
        "intermediates/dex/release/**/*.dex",
        "intermediates/**/release/**/*.dex",
    ):
        files = sorted(app_build.glob(pattern))
        if files:
            return files
    raise SystemExit("Could not find classes.dex")


def find_dir(app_build: Path, patterns: tuple[str, ...]) -> Path | None:
    for pattern in patterns:
        matches = [p for p in app_build.glob(pattern) if p.is_dir()]
        if matches:
            return sorted(matches, key=lambda p: p.stat().st_mtime, reverse=True)[0]
    return None


def add_tree(zf: zipfile.ZipFile, root: Path, arc_prefix: str) -> None:
    if not root.exists():
        return
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        name = f"{arc_prefix}/{rel}" if arc_prefix else rel
        if name in zf.namelist():
            continue
        zf.write(path, name, compress_type=zipfile.ZIP_DEFLATED)


def read_props(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    if not path.exists():
        return data
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip()
    return data


def signing(android_dir: Path) -> tuple[Path, str, str, str]:
    props = read_props(android_dir / "key.properties")
    if props.get("storeFile"):
        store = Path(props["storeFile"])
        if not store.is_absolute():
            store = android_dir / "app" / store
        if store.exists():
            return (
                store,
                props.get("storePassword", ""),
                props.get("keyAlias", "nazzil"),
                props.get("keyPassword", props.get("storePassword", "")),
            )
    debug = Path.home() / ".android" / "debug.keystore"
    if debug.exists():
        return debug, "android", "androiddebugkey", "android"
    raise SystemExit("No release keystore or debug.keystore found")


def run(cmd: list[str], redact: str | None = None) -> None:
    shown = [c.replace(redact, "***") if redact and redact in c else c for c in cmd]
    print("+", " ".join(shown))
    subprocess.check_call(cmd)


def main() -> int:
    root = flutter_root()
    app_build = root / "build" / "app"
    android_dir = root / "android"
    out_dir = app_build / "outputs" / "flutter-apk"
    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / "app-release.apk"
    tools = build_tools()
    work = app_build / "stitch-release"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)

    ap_ = find_ap_(app_build)
    dex_files = find_dex(app_build)
    native = find_dir(
        app_build,
        (
            "intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib",
            "intermediates/merged_native_libs/release/**/lib",
            "intermediates/stripped_native_libs/release/**/lib",
            "intermediates/flutter/release/libs",
        ),
    )
    assets = find_dir(
        app_build,
        (
            "intermediates/assets/release/mergeReleaseAssets",
            "intermediates/assets/release/**",
        ),
    )
    java_res = find_dir(
        app_build,
        (
            "intermediates/java_res/release/processReleaseJavaRes/out",
            "intermediates/java_res/release/**",
        ),
    )

    unsigned = work / "unsigned.apk"
    stored = {"resources.arsc", "AndroidManifest.xml"}
    with zipfile.ZipFile(ap_) as src, zipfile.ZipFile(
        unsigned, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as zf:
        for info in src.infolist():
            data = src.read(info.filename)
            out = zipfile.ZipInfo(filename=info.filename)
            out.date_time = info.date_time
            out.compress_type = (
                zipfile.ZIP_STORED if info.filename in stored else zipfile.ZIP_DEFLATED
            )
            zf.writestr(out, data)
        for index, dex in enumerate(dex_files):
            name = "classes.dex" if index == 0 else f"classes{index + 1}.dex"
            if name not in zf.namelist():
                zf.write(dex, name, compress_type=zipfile.ZIP_DEFLATED)
        if native:
            arm = native / "arm64-v8a"
            if arm.is_dir():
                add_tree(zf, arm, "lib/arm64-v8a")
            else:
                add_tree(zf, native, "lib")
        if assets:
            add_tree(zf, assets, "assets")
        if java_res:
            add_tree(zf, java_res, "")

    aligned = work / "aligned.apk"
    run([str(tools / "zipalign"), "-f", "-p", "4", str(unsigned), str(aligned)])

    store, store_pass, alias, key_pass = signing(android_dir)
    signed = work / "signed.apk"
    pass_file = work / "ks.pass"
    key_file = work / "key.pass"
    pass_file.write_text(store_pass)
    key_file.write_text(key_pass)
    try:
        run(
            [
                str(tools / "apksigner"),
                "sign",
                "--ks",
                str(store),
                "--ks-pass",
                f"file:{pass_file}",
                "--ks-key-alias",
                alias,
                "--key-pass",
                f"file:{key_file}",
                "--out",
                str(signed),
                str(aligned),
            ]
        )
    finally:
        pass_file.unlink(missing_ok=True)
        key_file.unlink(missing_ok=True)
    run([str(tools / "apksigner"), "verify", "--verbose", str(signed)])
    shutil.copy2(signed, dest)
    print(f"Wrote {dest} ({dest.stat().st_size} bytes)")
    badging = subprocess.check_output([str(tools / "aapt"), "dump", "badging", str(dest)], text=True)
    first = badging.splitlines()[0]
    print(first)
    if "versionCode='22'" not in first or "versionName='1.3'" not in first:
        raise SystemExit(f"APK is missing versionCode/versionName: {first}")
    if "AndroidManifest.xml" not in zipfile.ZipFile(dest).namelist():
        raise SystemExit("APK is missing AndroidManifest.xml")
    return 0


if __name__ == "__main__":
    sys.exit(main())
