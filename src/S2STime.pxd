# cython: language_level=3

cdef extern from "include/S2STime.h":
    enum: SHAREDDLL

    ctypedef struct S2S_Time:
        int year
        int month
        int day
        int hour
        int minute
        int second
        int milliseconds

    void s2s_TimeInit (S2S_Time *t) nogil
    S2S_Time *s2s_GetSystemTime(S2S_Time *time) nogil
    int s2s_CmpTime(S2S_Time *t1, S2S_Time *t2) nogil
    S2S_Time *s2s_AddToTime (S2S_Time *t, unsigned int msecs, unsigned int days) nogil
    unsigned int s2s_TimeDuration (S2S_Time *von, S2S_Time *to) nogil
    void s2s_TimePrint (S2S_Time *t, char *str)

cdef class PyS2STime:

    cdef S2S_Time* _time

cpdef void py_time_init() nogil
cpdef int py_cmp_time(PyS2STime py_time1,PyS2STime py_time2)
cpdef PyS2STime py_add_to_time(PyS2STime py_time, unsigned int msecs,unsigned int days)
cpdef PyS2STime py_get_system_time(PyS2STime py_time)
cdef bytes py_time_print(S2S_Time* py_time)
cpdef unsigned int py_time_duration(PyS2STime py_time1, PyS2STime py_time2)