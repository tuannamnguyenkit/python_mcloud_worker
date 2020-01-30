# cython: language_level=3
from MCloud cimport MCloudWrap
from WorkerOpenFile cimport WorkerOpenFile
cimport WorkerUserData

cdef class WorkerUserData:


    def __cinit__(self, MCloudWrap mcloud, char* start_time):
        self.mcloud = mcloud
        self.start_time = start_time
"""
self.open_files = 1
"""

