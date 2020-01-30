# cython: language_level=3
cimport MCloud as mc
import MCloud
from MCloudPacketRCV cimport mcloudGetNextPacket, MCloudPacket, mcloudPacketDeinit
from MCloudPacketRCV cimport S2S_Success, S2S_Error
from libc.stdlib cimport free, malloc
from libc.stdio cimport printf

cdef class MCloudPacketRCV:
    """
    MCloud packets builder which are meant to be received
    """
    def __cinit__(self, mc.MCloudWrap mcloud_w not None):
        self._mcloud = <mc.MCloud*> mcloud_w._mcloud


            #printf("MCLOUD_PACKET_RCV Expecting new packet.")
        self._mcloud_packet = <MCloudPacket*> mcloudGetNextPacket(
            <mc.MCloud*?> mcloud_w._mcloud)
        mcloud_w.rcv_packet_count =+1
        if self._mcloud_packet is NULL:
            msg = "Get Next Packet! Insufficient memory!"
            self.result(msg, 1)
            raise MemoryError(msg)
        else:
            # print("MCLOUD_PACKET_RCV Created empty Packet.")
            pass

    # def __dealloc__(self):
    #     if self._mcloud_packet != NULL:
    #         mcloudPacketDeinit(<MCloudPacket*> self._mcloud_packet)


    def packet_type(self):
        return self._mcloud_packet.packetType if self._mcloud_packet is not NULL else None
    @property
    def xml_string(self):
        return self._mcloud_packet.xmlString if self._mcloud_packet is not NULL else None
    @property
    def status_description(self):
        return self._mcloud_packet.statusDescription if self._mcloud_packet is not NULL else None
    @property
    def session_id(self):
        return self._mcloud_packet.sessionID if self._mcloud_packet is not NULL else None

    def stream_id(self):
        return self._mcloud_packet.streamID if self._mcloud_packet is not NULL else None

    def data_type(self):
        return self._mcloud_packet.dataType if self._mcloud_packet is not NULL else None

    cpdef int result(self, int res, mes):
        log = "MCLOUD_PACKET_RCV"
        if res == 0:
            print("{} SUCCESS calling function: {}".format(log, mes))
            return S2S_Success
        print ("{} ERROR calling function: {}".format(log, mes))
        return S2S_Error


