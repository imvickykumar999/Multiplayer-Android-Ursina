# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_data_files, collect_submodules, collect_dynamic_libs
import os

datas = [
    ('assets', 'assets'),
    ('client.ico', '.'),
]
datas += collect_data_files('ursina')

# Filter panda3d data files to avoid duplicating dynamic libraries and dev headers
panda3d_datas = collect_data_files('panda3d')
datas += [(src, dst) for src, dst in panda3d_datas if not src.lower().endswith(('.dll', '.lib', '.pdb', '.h', '.exe'))]

datas += collect_data_files('direct')
datas += collect_data_files('screeninfo')

# Filter pygame to essential data only (exclude heavy html documentation, examples, and duplicate binaries)
pygame_datas = collect_data_files('pygame')
datas += [(src, dst) for src, dst in pygame_datas if 'docs' not in dst.lower() and 'examples' not in dst.lower() and not src.lower().endswith(('.dll', '.lib', '.h', '.html', '.js', '.css', '.rst', '.pyi'))]

# Dynamic libraries: filter out heavy unused Panda3D plugins (FFmpeg video decoder, TinyDisplay software rasterizer, Assimp importer, FMOD, VR, ODE)
panda3d_libs = collect_dynamic_libs('panda3d')
unused_libs = {
    'avcodec-55.dll', 'avformat-55.dll', 'avutil-52.dll',
    'swscale-2.dll', 'swresample-0.dll', 'libp3tinydisplay.dll',
    'libp3assimp.dll', 'fmodex64.dll', 'libp3fmod_audio.dll',
    'libp3ffmpeg.dll', 'libp3vrpn.dll', 'libpandaode.dll',
}
binaries = [(src, dst) for src, dst in panda3d_libs if os.path.basename(src).lower() not in unused_libs]
binaries += collect_dynamic_libs('pygame')

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
hiddenimports += [
    mod for mod in collect_submodules('direct')
    if not mod.startswith(('direct.p3d', 'direct.directscripts', 'direct.leveleditor', 'direct.cluster'))
]
hiddenimports += collect_submodules('panda3d')
hiddenimports += collect_submodules('ursina')

excludes = [
    # Machine learning, Data science, and heavy dev tools in the environment
    'scipy',
    'pandas',
    'numpy',
    'matplotlib',
    'torch',
    'transformers',
    'cv2',
    'IPython',
    'jupyter',
    'playwright',
    'selenium',

    # Security-sensitive modules that trigger antivirus heuristics
    'cryptography',
    'scapy',
    'pynput',

    # Unused Google and cloud libraries
    'google',
    'googleapiclient',
    'googleapis_common_protos',
    'proto',
    'protobuf',
    'opentelemetry',

    # Unused networking and packaging utilities
    'requests',
    'urllib3',
    'certifi',
    'cffi',
    'pycparser',
    'pip',

    # Unused Python standard library modules to trim size and attack surface
    'sqlite3',
    'unittest',
    'test',
    'pydoc',
    'doctest',
    'difflib',
    'pdb',
    'profile',
    'pstats',
    'curses',
    'pty',
    'smtplib',
    'xmlrpc',
    'tkinterweb',
]

a = Analysis(
    ['main.py'],
    pathex=['.'],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    noarchive=False,
    optimize=1,
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
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['client.ico'],
    version='version_info.txt',
)

