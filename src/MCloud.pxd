# cython: language_level=3
from libc.stdio cimport FILE
from MCloudPacketSND cimport MCloudPacketSND
from MCloudPacketRCV cimport MCloudPacketRCV
from UserData cimport UserData
cimport S2STime as s2stime
cdef extern from "Python.h":
    void Py_Initialize()
cdef extern from "include/MCloud.h":
    enum: SHAREDDLL

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

    ctypedef struct MCloudWordToken:
        int          index
        char        *internal
        char        *written
        char        *spoken
        float        confidence
        unsigned int startTime
        unsigned int stopTime
        int          isFiller

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

    ctypedef enum S2S_Result:
        S2S_Success = 0
        S2S_Error = 1
    # MCloud object
    ctypedef struct MCloud
    ctypedef int MCloudCallbackFct(MCloud *cloudP, void *userData)
    ctypedef int MCloudPacketCallbackFct(MCloud *cloudP, MCloudPacket *p, void *userData)
    void mcloudPacketDeinit (MCloudPacket *p);
    MCloud *mcloudCreate2(const char *name, int mode, const char *username, const char *password)
    MCloud* mcloudCreate (const char *name, int mode)
    void mcloudFree(MCloud *cloudP)
    MCloudWordToken* mcloudWordTokenArrayCreate (int n)
    MCloudPacket* mcloudPacketInitFromWordTokenA (MCloud *cloudP, const char* startTime, const char* stopTime, unsigned int startOffset, unsigned int stopOffset, const char *fingerPrint, MCloudWordToken *tokenA, int tokenN)
    MCloudPacket* mcloudPacketInitFromText (MCloud *cloudP, const char* startTime, const char* stopTime, unsigned int startOffset, unsigned int stopOffset, const char *fingerPrint, const char *text)
    S2S_Result mcloudSendPacketAsync (MCloud *cloudP, MCloudPacket *p, void *userData) nogil
    void mcloudWordTokenArrayFree (MCloudWordToken* tokenA, int n);
    S2S_Result mcloudAddFlowDescription2(MCloud *cloudP, const char *username,
                                         const char *password,
                                         int logging, const char *language,
                                         const char *name,
                                         const char *description)
    S2S_Result mcloudConnect(MCloud *cloudP, const char *host, int port)
    S2S_Result mcloudAnnounceOutputStream(MCloud *cloudP, const char *type,
                                          const char *fingerPrint,
                                          const char *streamID,
                                          const char *specifier)
    void mcloudSetDataCallback(MCloud *cloudP, MCloudPacketCallbackFct *callback)
    void mcloudSetErrorCallback(MCloud *cloudP, MCloudType queueType, MCloudCallbackFct *callback, void*
    userData)
    void mcloudSetBreakCallback(MCloud *cloudP, MCloudType queueType, MCloudCallbackFct *callback, void*
    userData)
    void mcloudSetFinalizeCallback(MCloud *cloudP, MCloudCallbackFct *callback, void *userData)
    void mcloudSetInitCallback (MCloud *cloudP, MCloudPacketCallbackFct *callback, void *userData)
    S2S_Result mcloudRequestInputStream(MCloud *cloudP, const
    char *type, const char *fingerPrint, const char *streamID, char *info,
                                        int infoN)
    S2S_Result mcloudWaitFinish(MCloud *cloudP, MCloudType queueType, int done) nogil
    S2S_Result mcloudBreak(MCloud *cloudP, MCloudType queueType) nogil
    S2S_Result mcloudDisconnect(MCloud *cloudP)

    S2S_Result mcloudSendBinaryFile(MCloud *cP, FILE *f, int chunkSize, char *filename, char *mimeType,
                                    char *fingerPrint) nogil
    S2S_Result mcloudPacketGetAudio (MCloud *cloudP, MCloudPacket *p, short **sampleA, int *sampleN)
    S2S_Result mcloudSendBinaryFileAsync(MCloud *cP, FILE *f, int chunkSize, char *filename, char *mimeType,
                                         char *fingerPrint, void *userData) nogil
    S2S_Result mcloudSendPacket(MCloud *cloudP, MCloudPacket *p) nogil
    S2S_Result mcloudSendPacketAsync(MCloud *cloudP, MCloudPacket *p, void *userData) nogil
    S2S_Result mcloudPacketGetText(MCloud *cloudP, MCloudPacket *p, char ** text) nogil
    S2S_Result mcloudSetAudioEncoder2(MCloud *cp, char *codec, int sampleRate, int bitRate, int channels)
    S2S_Result mcloudRequestForDisplay(MCloud *cloudP)
    S2S_Result mcloudProcessDataAsync(MCloud *cloudP, MCloudPacket *p, void *userData)
    S2S_Result mcloudSendDone(MCloud *cloudP)
    S2S_Result mcloudSendFlush (MCloud *cloudP) nogil
    S2S_Result mcloudAddService (MCloud *cloudP, const char *name, const char *service, const char *inputFingerPrint,
                                 const char *inputType, const char *outputFingerPrint, const char *outputType,
                                 const char *specifier)
    S2S_Result mcloudWaitForClient (MCloud *cloudP, char **streamID)
    int mcloudPending (MCloud *cloudP, MCloudType queueType)
    char*base64_encode(const char *data, size_t input_length, size_t *output_length)


cdef class MCloudWrap:
    cdef:
        MCloud* _mcloud
        object __weakref__
        int rcv_packet_count
        list translations


    cpdef int add_flow_description(self, const char *language, const char *name,
                                   const char *description)
    cpdef int connect(self, const char *host, int port)
    cpdef int disconnect(self)
    cpdef int announce_output_stream(self, const char *type, const char*
    fingerprint, const char *stream_id, const char *specifier)
    cpdef int request_input_stream(self, const char *type, const char
    *fingerPrint, const char *streamID)
    cpdef int request_for_display(self)
    cpdef int process_data_async(self, MCloudPacketRCV packet, callback)
    cpdef int pending_packets(self)
    cpdef int send_binary_file_async(self, char*file_name, int chunk_size, char *fingerPrint)
    cpdef int send_binary_file(self, char*file_name, int chunk_size, char *fingerprint)
    cpdef int send_packet_async(self, MCloudPacketSND packet)
    cpdef int send_packet(self, MCloudPacketSND packet)
    cpdef int set_audio_encoder(self, char *codec, int sample_rate, int bit_rate, int channels)
    cpdef int wait_for_finish(self, int done, queue_type)
    cpdef int stop_processing(self, queue_type)
    cpdef int add_service(self, const char *name, const char *service, const char *input_finger_print,
                              const char *input_type, const char *output_finger_print, const char *output_type,
                                const char *specifier)

    cpdef int send_done(self)
    cpdef int send_flush(self)
    cdef void print_translation(self)
    cpdef int wait_for_client(self, char* stream_id)
    cdef void append_translation(self, char* translation)
    cpdef int result(self, int res, mes)

    @staticmethod
    cdef int py_clb_wrapper(MCloud* mcloud, void*user_data)


    @staticmethod
    cdef int py_client_data_clb_wrapper(MCloud* mcloud, MCloudPacket*packet, void*user_data)

    @staticmethod
    cdef int py_finalizeCallback (MCloud *cP, void *userData)
    @staticmethod
    cdef int py_breakCallback (MCloud *cP, void *userData)
    @staticmethod
    cdef int py_errorCallback (MCloud *cP, void *userData)

cdef int py_worker_data_clb_wrapper(MCloud* mcloud, MCloudPacket*packet, void*user_data)

cdef int py_worker_init_clb_wrapper(MCloud* mcloud,MCloudPacket*packet, void*user_data)



cdef void timePrint (s2stime.S2S_Time *t, char *str)

cdef int parseTime (char *str, s2stime.S2S_Time *t)



cdef char* callback(int number,short *sampleA,void *f)

ctypedef char*  (*datacallback)(int number,short *sampleA,void *user_data)

cdef char* python_data_callback(datacallback user_func,int number,short *sampleA,void *user_data)

ctypedef void  (*init_callback)(void *user_data)

cdef void python_init_callback(init_callback user_func,void *user_data)


cdef void  function_init_callback(void *f)