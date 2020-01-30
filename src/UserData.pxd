# cython: language_level=3
from MCloud cimport MCloudWrap

cdef class UserData:
    cdef:
        MCloudWrap mcloud
        int proceed


