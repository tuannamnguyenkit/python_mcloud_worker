# cython: language_level=3
from MCloud cimport MCloudWrap
from WorkerOpenFile cimport WorkerOpenFile

cdef class WorkerUserData:
    cdef:
        MCloudWrap mcloud
        char* start_time




"""
WorkerOpenFile open_files
"""

