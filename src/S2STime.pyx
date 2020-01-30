# cython: language_level=3

cimport S2STime as s2stime
from libc.stdio cimport printf
from libc.stdlib cimport malloc, free, realloc

cdef class PyS2STime:

    def __cinit__(self):
        cdef s2stime.S2S_Time* _time
        time_temp = <s2stime.S2S_Time*> malloc(sizeof(s2stime.S2S_Time))
        if time_temp is NULL:
            raise MemoryError("PyS2STime ERROR No memory to make object!")
        if time_temp is not NULL:
                self._time = <s2stime.S2S_Time*> s2stime.s2s_GetSystemTime(<s2stime.S2S_Time*>
                                                                       time_temp)
        if self._time is NULL:
            printf("INFO PyS2STime NULL Pointer returned!")
            raise MemoryError("PyS2STime ERROR Null pointer returned!")

    def __dealloc__(self):
        """
        Free an PyS2STime object
        """
        if self._time is not NULL:
            free(self._time)


    def year(self):
        return self._time.year if self._time is not NULL else None


    def month(self):
        return self._time.month if self._time is not NULL else None


    def day(self):
        return self._time.day if self._time is not NULL else None


    def hour(self):
        return self._time.hour if self._time is not NULL else None


    def minute(self):
        return self._time.minute if self._time is not NULL else None


    def second(self):
        return self._time.second if self._time is not NULL else None


    def milliseconds(self):
        return self._time.milliseconds if self._time is not NULL else None

# Utility functions for time usage
cpdef void py_time_init() nogil:
    cdef s2stime.S2S_Time* temp = <s2stime.S2S_Time*> malloc(sizeof(s2stime.S2S_Time))
    try:
        s2stime.s2s_TimeInit(<s2stime.S2S_Time*> temp)
    finally:
        free(temp)
    printf("INFO PyS2STime Time successful initialized")

cpdef PyS2STime py_get_system_time(PyS2STime py_time) :

    cdef s2stime.S2S_Time* temp2 = s2s_GetSystemTime(py_time._time)
    s = PyS2STime()
    s._time = temp2
    return  s
    
cpdef PyS2STime py_add_to_time(PyS2STime py_time, unsigned int msecs,
                                      unsigned int days) :
    cdef s2stime.S2S_Time*  temp2 = s2s_AddToTime(py_time._time,msecs, days)

    s = PyS2STime()
    s._time = temp2
    return s

cpdef int py_cmp_time(PyS2STime py_time1, PyS2STime py_time2) :

    cdef int res = s2s_CmpTime(py_time1._time,py_time2._time)

    return res

cdef bytes py_time_print(s2stime.S2S_Time* py_time):
    cdef:
        char* c_string = <char*> malloc(1024*sizeof(char))
    s2stime.s2s_TimePrint(<s2stime.S2S_Time*> py_time, <char*> c_string)
    try:
        py_string = <bytes> c_string
    finally:
        free(c_string)
    return py_string

cpdef unsigned int py_time_duration(PyS2STime py_time1, PyS2STime py_time2) :
    cdef int res =  s2s_TimeDuration(py_time1._time,py_time2._time)

    return res