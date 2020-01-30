# cython: language_level=3
from libc.stdio cimport FILE

cdef class WorkerOpenFile:
    cdef:
        char* name
        FILE* file
        WorkerOpenFile next


