# cython: language_level=3
import MCloud

cimport MCloud as mc

cdef extern from "include/MCloud.h":
    enum: SHAREDDLL
    ctypedef enum S2S_Result:
        S2S_Success = 0
        S2S_Error = 1

    ctypedef enum MCloudType:
        MCloudModeWorker = 1
        MCloudModeClient  # 2
        MCloudData  # 3
        MCloudDone  # 4
        MCloudError  # 5
        MCloudReset  # 6
        MCloudFlush  # 7
        MCloudAudio  # 8
        MCloudText  # 9
        MCloudImage  # 10
        MCloudMixed  # 11
        MCloudBinary  # 12
        MCloudSendingQueue  # 13
        MCloudProcessingQueue  # 14
        MCloudCustomization  # 15
        MCloudKeepAlive  # 16

    ctypedef struct MCloudPacket:
        MCloudType packetType
        MCloudType dataType
        char *sessionID
        char *streamID
        char *fingerPrint
        char *creator
        char *start
        char *stop
        unsigned int startOffset
        unsigned int stopOffset
        char *statusDescription
        char *userID
        char *cmType
        char *revision
        char *xmlString

    void mcloudPacketDeinit(MCloudPacket* p)
    MCloudPacket *mcloudPacketInitFromBinary (mc.MCloud* cP, const char* startTime, const char* stopTime,
                                              const char *fingerPrint, const char *filename,
                                              const char *mimetype, const unsigned char *bytes,
                                              int bytesN, int last) nogil
    MCloudPacket* mcloudPacketInitFromAudio (mc.MCloud* cloudP, const char* startTime, const char* stopTime,
                                             const char *fingerPrint, const short *sampleA, int sampleN, int isFinal)nogil


cdef class MCloudPacketSND:
    cdef:
        MCloudPacket* _mcloud_packet
        mc.MCloud* _mcloud