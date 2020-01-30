# cython: language_level=3
cimport MCloud as mc
import MCloud
from MCloudPacketSND cimport mcloudPacketInitFromBinary, mcloudPacketInitFromAudio, mcloudPacketDeinit
from libc.stdio cimport printf
from libc.stdlib cimport free
from posix.unistd cimport usleep


cdef class MCloudPacketSND:
    """
    MCloud packets builder which are for sending
    """
    def __cinit__(self, mc.MCloudWrap mcloud_w not None, bytes start_time, bytes stop_time, fingerprint, file_name,
                  unsigned
                  char*bytes, int bytes_n, int last):
        self._mcloud = <mc.MCloud*> mcloud_w._mcloud
        cdef:
             char* c_start_time
             char* c_end_time
             char* c_fingerprint
        c_start_time = <char*> start_time
        c_end_time = <char*> stop_time
        #printf("%s\n", c_end_time)
        c_fingerprint = <char*> fingerprint

        with nogil:
            #printf("SND Gil released!\n")
            self._mcloud_packet = <MCloudPacket*> mcloudPacketInitFromAudio(<mc.MCloud*?> self._mcloud,
                                                                        c_start_time, c_end_time, c_fingerprint,
                                                                        <const short*> bytes,
                                                                        bytes_n, last)
            #usleep(256000)
        #print("SND Gil acquired!")
        if self._mcloud_packet is NULL:
            msg = "MCLOUD_PACKET_SND ERROR insufficient memory!"
            raise MemoryError(msg)

    def __dealloc__(self):
        if self._mcloud_packet is not NULL:
            mcloudPacketDeinit(self._mcloud_packet)

    @property
    def fingerprint(self):
        return self._mcloud_packet.fingerPrint if self._mcloud_packet is not NULL else None
    @property
    def session_id(self):
        return self._mcloud_packet.sessionID if self._mcloud_packet is not NULL else None
    @property
    def stream_id(self):
        return self._mcloud_packet.streamID if self._mcloud_packet is not NULL else None
    @property
    def xml_string(self):
        return self._mcloud_packet.xmlString if self._mcloud_packet is not NULL else None
