# cython: language_level=3

from libc.stdio cimport FILE
from time import sleep
from WorkerUserData cimport WorkerUserData
from WorkerOpenFile cimport WorkerOpenFile
from MCloudPacketRCV cimport MCloudPacketRCV