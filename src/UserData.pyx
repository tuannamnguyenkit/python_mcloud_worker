# cython: language_level=3
from MCloud cimport MCloudWrap
import MCloud
cdef class UserData:

    def __cinit__(self, mcloud not None):
        self.mcloud = mcloud
        self.proceed = 1

    def __str__(self):
        return "\n>>MCloud: {}\n>>Proceed: {}".format(self.mcloud, self.proceed)

    @property
    def mcloud(self):
        return self.cloud_p

    @mcloud.setter
    def mcloud(self, m not None):
        self.mcloud = <MCloudWrap> m

    @property
    def proceed(self):
        return self.proceed

    @proceed.setter
    def proceed(self, m not None):
        self.proceed = <int> m
