import sys
import os

block_cipher = None

datas = [
    ('assets/icon.icns', 'assets'),
    ('assets/icon.ico', 'assets'),
    ('assets/space-warp-icon.png', 'assets'),
]

a = Analysis(['src/space_warp/__main__.py'],
             pathex=['.', 'src'],
             binaries=None,
             datas=datas,
             hiddenimports=[
                 'PyQt6.QtCore',
                 'PyQt6.QtWidgets',
                 'PyQt6.QtGui',
                 'PyQt6.sip',
                 'AppKit',
                 'Quartz',
                 'ApplicationServices',
                 'yaml',
                 'space_warp.config',
                 'space_warp.window_manager',
                 'space_warp.snapshot_manager',
                 'space_warp.main_window',
                 'space_warp.permissions',
             ],
             hookspath=None,
             runtime_hooks=None,
             excludes=[
                 'tkinter',
                 'matplotlib',
                 'numpy',
                 'scipy',
                 'pandas',
             ],
             cipher=block_cipher,
             noarchive=False)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(pyz,
          a.scripts,
          exclude_binaries=True,
          name='space-warp',
          debug=False,
          strip=False,
          upx=True,
          console=False,
          icon='assets/icon.ico')

coll = COLLECT(exe,
               a.binaries,
               a.zipfiles,
               a.datas,
               strip=False,
               upx=True,
               name='SpaceWarp')

app = BUNDLE(coll,
             name='SpaceWarp.app',
             icon='assets/icon.icns',
             bundle_identifier='com.spacewarp',
             info_plist={
               'CFBundleName': 'SpaceWarp',
               'CFBundleDisplayName': 'SpaceWarp',
               'CFBundleVersion': '0.1.0',
               'CFBundleShortVersionString': '0.1.0',
               'NSPrincipalClass': 'NSApplication',
               'NSHighResolutionCapable': True,
               'LSMinimumSystemVersion': '10.14.0',
               'NSRequiresAquaSystemAppearance': False,
               'NSAppleEventsUsageDescription': 'SpaceWarp automates window management.',
               'LSUIElement': False,
              }
             )
