# cython: language_level=3
from libc.stdio cimport FILE, fopen, fclose
cimport WorkerOpenFile

cdef class WorkerOpenFile:

    def __cinit__(self, char* name, char* file_name):
        self.name = name
        cdef FILE* cfile = fopen(file_name, "rb")
        self.file = <FILE*> cfile
        fclose(cfile)

    def __dealloc__(self):
        fclose(self.file)
