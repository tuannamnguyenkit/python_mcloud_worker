import os
import shutil
import traceback
from Cython.Build import cythonize
from Cython.Distutils import build_ext
from distutils.command.build_ext import build_ext
from distutils.core import setup, Extension


class BuildFailed(Exception):
    pass

LIB_DIR = ["linux_lib64"]
LIBS = ["audioutils", "avcodec", "avformat", "avresample", "avutil",
        "gmp", "gnutls", "gnutls-xssl", "gnutlsxx", "hogweed", "MCloud",
        "nettle", "opus", "speex"]

SOURCES = ["MCloud.pyx", "MCloudPacketSND.pyx", "MCloudPacketRCV.pyx", "UserData.pyx", "S2STime.pyx", "ClientBiDirectional.pyx"]


def clean_build():
    # clean previous build
    for root, dirs, files in os.walk(".", topdown=False):
        for name in files:
            if (name.startswith("isl_mcloud_wrapper") and not (
                    name.endswith(".pyx") or name.endswith(".pxd"))):
                os.remove(os.path.join(root, name))
        for name in dirs:
            if name == "build":
                shutil.rmtree(name)


def build_extension():
    clean_build()
    try:
        ext = Extension("*", ["*.pyx"],
                        include_dirs=["/home/mtasr/Desktop/mcloud_wrapper/src/include", "/home/mtasr/Desktop/mcloud_wrapper/src/audio", "."],
                        library_dirs=LIB_DIR,
                        libraries=LIBS,
                        extra_link_args=["-L" + os.getcwd()])

        c_source = cythonize(ext, language_level="3", gdb_debug=True, annotate=True)

        setup(name="mcloud_wrapper",
              version="1.0",
              description="Wrapper for MCLoud API",
              author="Siyar Yikmis",
              author_email="usfqg@student.kit.edu",
              cmdclass={'build_ext': build_ext},
              ext_modules=c_source)

    except (Exception, SystemExit) as e:

        print("THIS IS AN ERROR", e)
        traceback.print_exc()


try:
    build_extension()
except BuildFailed:
    print()
    print('*' * 80)
    print("An error occurred while trying to "
          "compile with the C extension enabled")
    print('*' * 80)
    print()

