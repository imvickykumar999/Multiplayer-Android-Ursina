# -*- mode: python ; coding: utf-8 -*-

excludes = [
    # Heavy game engines & GUI frameworks not used by dedicated server
    'ursina',
    'panda3d',
    'direct',
    'pygame',
    'PIL',
    'Pillow',
    'tkinter',
    'tkinterweb',

    # Data science, ML & scraping tools
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

    # Security/heuristic triggering libraries
    'cryptography',
    'scapy',
    'pynput',

    # Cloud & network utilities
    'google',
    'googleapiclient',
    'googleapis_common_protos',
    'proto',
    'protobuf',
    'opentelemetry',
    'requests',
    'urllib3',
    'certifi',
    'cffi',
    'pycparser',
    'pip',

    # Unused stdlib modules
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
]

a = Analysis(
    ['main.py'],
    pathex=['.'],
    binaries=[],
    datas=[
        ('server.ico', '.'),
    ],
    hiddenimports=['art', 'json', 'colorama', 'psutil'],
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
    name='server',
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
    icon=['server.ico'],
    version='version_info.txt',
)
