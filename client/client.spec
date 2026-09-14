# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_data_files, collect_submodules, collect_dynamic_libs
import os

datas = [
    ('assets', 'assets'),
    ('client.ico', '.'),
]
datas += collect_data_files('ursina')
datas += collect_data_files('panda3d')
datas += collect_data_files('direct')
datas += collect_data_files('screeninfo')
datas += collect_data_files('pygame')

binaries = collect_dynamic_libs('panda3d')

hiddenimports = [
    'direct',
    'panda3d',
    'ursina',
    'pygame',
    'PIL',
    'PIL.Image',
    'PIL.ImageTk',
    'psutil',
    'screeninfo',
    'tkinter',
    'tkinter.ttk',
    'tkinter.font',
    'network',
    'floor',
    'map',
    'player',
    'enemy',
    'bullet',
]
hiddenimports += collect_submodules('direct')
hiddenimports += collect_submodules('panda3d')
hiddenimports += collect_submodules('ursina')

a = Analysis(
    ['main.py'],
    pathex=['.'],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='client',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['client.ico'],
)
