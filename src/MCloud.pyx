# cython: language_level=3

from cython.view cimport array as cvarray
from libc.string cimport strcpy, strlen
from MCloudPacketSND cimport MCloudPacketSND
from MCloudPacketRCV cimport MCloudPacketRCV
from WorkerUserData cimport WorkerUserData
from UserData cimport UserData
import socket, time
import weakref
from libc.stdlib cimport malloc, free, realloc

from libc.stdio cimport FILE, fopen, fclose, feof, fread, printf,scanf,sprintf,sscanf
from base64 import b64encode, b64decode
import threading, sys
cimport MCloud as mcloud_h
import cython
cimport cython
import os
import gc
import psutil

cimport S2STime as s2stime
from libc.string cimport strdup



cdef class MCloudWrap:


    _instances=set()

    def __cinit__(self, const char *name, int mode):
        """
        Create an MCloud object with a specific name and mode
        :param name:    string      descriptive name of the worker or client
        :param mode:    int         working mode, "MCloudModeworker" or 
                                    "MCloudModeClient"
        :return:                    reference to an MCloud object or MemoryError
        """
        self._mcloud = <mcloud_h.MCloud*> mcloud_h.mcloudCreate(name, mode)
        self.rcv_packet_count = 0
        self.translations =[]
        if self._mcloud == NULL:
            msg = "MCLOUD_WRAPPER ERROR insufficient memory creating MCloud Object {}!".format(
                name)
            raise MemoryError(msg)

        print("MCLOUD_WRAPPER SUCCESS creating MCloud Object {} {}!".format(
            name, mode))

    def __dealloc__(self):
        """
        Free an MCloud object
        """
        if self._mcloud is not NULL:
            mcloud_h.mcloudFree(self._mcloud)

    @classmethod
    def get_instances(cls):
        dead = set()
        for ref in cls._instances:
            obj = ref()
            if obj is not None:
                yield obj
            else:
                dead.add(ref)
        cls._instances -= dead


    cpdef int add_flow_description(self, const char *language, const char *name,
                                   const char *description):
        """
        Add a flow description of a client to an MCloud object. This function
        has to be called after an MCloud object has been created and before 
        connecting to the MCloud. A client can add more than one flow being 
        just translations of the same description. Therefore, the password 
        and logging hast to be same over all flows.
        
        :param language:    string  descriptive language identifier of the 
        flow, e.g. English
        :param name:        string  name of the flow, e.g. title of a talk
        :param description: string  additional description of the flow, 
        e.g. abstract
        :return:            S2S_Success if no error occurs
        """

        cdef int res = mcloud_h.mcloudAddFlowDescription2(self._mcloud,
                                                            NULL,
                                                          NULL, 0,
                                                          language,
                                                          name, description)
        mes = "Add flow description {} {} {}".format(language, name,
                                                     description)
        return self.result(res, mes)

    cpdef int connect(self, const char *host, int port):
        """
        Connect to the MCloud server running on the host at port given. This
        function has to be called after an MCloud object has been created
        and before waiting for a client or worker.
    
        :param host:    string  host name
        :param port:    int     port number
        :return:        S2S_Success if no error occurs
        """
        cdef int res = <int> mcloud_h.mcloudConnect(self._mcloud, host,
                                                    port)
        self._instances.add(weakref.ref(self))
        mes = "Connect to Mediator at {}:{} ".format(host, port)

        self.result(res, mes)

        return res

    cpdef int disconnect(self):
        """
        Disconnect from the MCloud server
        :return: S2S_Success if no error occurs
        """
        cdef int res = mcloud_h.mcloudDisconnect(self._mcloud)
        mes = "Disconnect from Mediator"
        return self.result(res, mes)

    cpdef int announce_output_stream(self, const char *type, const char*
    fingerprint, const char *stream_id, const char *specifier):
        """
        This function has to be called in order to request a specific input
        stream from the MCloud such as ASR or MT results. Otherwise,
        the client will not receive any data. This function has to be called
        after the client has been connected to the MCloud.
    
        :param type:        string  data type (audio, text, image)
        :param fingerprint: string  finger print of the data stream
        :param stream_id:   string  unique stream identifier
        :param specifier:   string  an additional specifier, i.e. a speaker a
        identifier
        :return:            S2S_Success if no error occurs
        """
        cdef int res = mcloud_h.mcloudAnnounceOutputStream(self._mcloud,
                                                           type,
                                                           fingerprint,
                                                           stream_id,
                                                           specifier)
        mes = "Announce Output stream {} {} {} {}".format(type,
                                                          fingerprint,
                                                          stream_id,
                                                          specifier)
        return self.result(res, mes)

    cpdef int request_input_stream(self, const char *type, const char
    *fingerprint, const char *stream_id):
        """
        This function has to be called in order to request a specific input 
        stream from the MCloud such as ASR or MT results. Otherwise, 
        the client will not receive any data. This function has to be called 
        after the client has been connected to the MCloud.
        
        :param type:        string  data type (audio, text, image)
        :param fingerprint: string  finger print of the data stream
        :param stream_id:    string  stream identifier of the (output) stream 
        :return:            S2S_Success if no error occurs
        """
        cdef:
            char info[4096]
            int res
        res = mcloud_h.mcloudRequestInputStream(self._mcloud, type,
                                                         fingerprint,
                                                         stream_id, info, 4096)
        printf("\nCLIENT INFO array: %s\n", info)
        #print("info: {}".format(py_string))
        mes = "Request input stream {} {} {}".format(<bytes> type, <bytes>
        fingerprint, <bytes> stream_id)
        return self.result(res, mes)

    cpdef int request_for_display(self):
        """
        By calling this function, the client requests the display of the output stream on the
        display server. For cancelling the request for display, the client needs to disconnect.
        """
        cdef int res = mcloud_h.mcloudRequestForDisplay(self._mcloud)
        mes = "Request for display"
        return self.result(res, mes)

    cpdef int process_data_async(self, MCloudPacketRCV packet, callback):
        """
        Process received packages asynchronously. This function can be used to process packets 
        asynchronously. The packages will be placed into an internal queue and processed in the 
        background by calling mcloudDataCallback. Callback functions are used to forward status 
        messages such as errors. Use mcloudBreak to  stop processing pending packages. Use 
        mcloudWaitFinish to wait until the last package has been processed. Packages are freed 
        automatically after they have been sent. While processing, the data callback 
        function is called for the next pending package. As soon as no more packages are 
        pending and mcloudWaitFinish has been called, the finalize callback function is called. 
        The error callback function may be called in case of errors, and the break callback 
        function if mcloudBreak has been called.
        
        :param packet:    MCloudPacketRCV      an MCloud packet
        :param callback:                       callback function to call
        :return:          S2S_Success if no error occurs 
        """

        cdef:
            int res = 1
            MCloudPacketRCV packet_


        res = mcloud_h.mcloudProcessDataAsync(self._mcloud,
                                              <mcloud_h.MCloudPacket*> packet._mcloud_packet,
                                              <void*> callback)


        mes = "Process data async"

        return 1

    cpdef int send_binary_file(self, char*file_name, int chunk_size, char *fingerprint):
        """
        Convenience function for sending the content of a whole file asynchronously.
        
        :param file_name:   string  name of the file being sent (set to NULL if not relevant)
        :param chunk_size:  int     bytes read from the file to be inserted in 1 packet
        :param fingerprint: string  finger print of the file
        :return:            S2S_Success if no error occurs
        """
        cdef:
            char*fname
            FILE*cfile
            int res

        fname = file_name
        cfile = fopen(fname, "rb")
        if cfile == NULL:
            raise FileNotFoundError(2, "No such file or directory: '{}'".format(file_name))

        res = mcloud_h.mcloudSendBinaryFile(self._mcloud,
                                            <FILE*> cfile, chunk_size, file_name,
                                            NULL, fingerprint)
        fclose(cfile)
        mes = "Send binary file async {} {}".format(file_name, fingerprint)
        return self.result(res, mes)

    cpdef int send_binary_file_async(self, char*file_name, int chunk_size, char *fingerprint):
        """
        Convenience function for sending the content of a whole file asynchronously.
        
        :param file_name:   string  name of the file being sent (set to NULL if not relevant)
        :param chunk_size:  int     bytes read from the file to be inserted in 1 packet
        :param fingerprint: string  finger print of the file
        :return:            S2S_Success if no error occurs
        """
        cdef:
            char*fname
            FILE*cfile
            int res

        fname = file_name
        cfile = fopen(fname, "rb")
        if cfile == NULL:
            raise FileNotFoundError(2, "No such file or directory: '{}'".format(file_name))

        res = mcloud_h.mcloudSendBinaryFileAsync(self._mcloud,
                                                 <FILE*> cfile, chunk_size, file_name,
                                                 NULL, fingerprint, NULL)

        fclose(cfile)
        mes = "Send binary file async {} {}".format(file_name, fingerprint)
        return self.result(res, mes)

    cpdef int send_packet(self, MCloudPacketSND packet):
        """
        Send a packet.This function has to be called to send a data packet to the MCloud. 
        The data packet has to be created in advance by using the packet handling classes. 
        :param packet:  MCloudPacketSND     an MCloud packet
        :return:        S2S_Success if no error occurs
        """
        cdef int res = mcloud_h.mcloudSendPacket(self._mcloud,
                                        <mcloud_h.MCloudPacket*> packet._mcloud_packet)
        mes = "Send packet"
        return 1
        #return self.result(res, mes)

    cpdef int send_packet_async(self, MCloudPacketSND packet):
        """
        Send a packet asynchronously. This function can be used for sending data packets 
        asynchronously. The packages will be placed into an internal queue and sent in the 
        background. Callback functions are used to forward status messages such as errors.
        Use mcloudBreak to stop sending pending packages. Use mcloudWaitFinish to wait 
        the last package has been sent. Packages are freed automatically after
        they have been sent. While sending, the error callback function may be called in case
        of errors and the break callback function if mcloudBreak has been called. As soon as 
        no more packages are pending and mcloudWaitFinish has been called, the finalize
        callback function is called.
        :param packet:  MCloudPacketSND     an MCloud packet
        :return:        S2S_Success if no error occurs
        """
        cdef:
            int res

        res = mcloud_h.mcloudSendPacketAsync(<mcloud_h.MCloud*> self._mcloud,
                                             <mcloud_h.MCloudPacket*> packet._mcloud_packet, <void*> NULL)
        mes = "Send packet async"
        return 1
        #return self.result(res, mes)

    cpdef int add_service(self, const char *name, const char *service, const char *input_finger_print,
                              const char *input_type, const char *output_finger_print, const char *output_type,
                                const char *specifier):
        """
        Add a service description of a worker to an MCloud object. This function has to be called after an MCloud object
        has been created and before connecting to the MCloud.
        :param name:                string  name of the worker
        :param service:             string  name of the service (asr, smt, tts, ...)
        :param input_finger_print:    string  service input finger print
        :param input_type:           string  data input type (audio, text)
        :param output_finger_print:   string  service output finger print
        :param output_type:          string  data output type (audio, text)
        :param specifier:           string  an additional specifier, i.e. a speaker identifier
        :return:                    S2S_Success if no error occurs
        """
        cdef:
            int res
        res = mcloud_h.mcloudAddService(<mcloud_h.MCloud*> self._mcloud, name, service, input_finger_print, input_type,
                                        output_finger_print, output_type, specifier)
        mes = "Add service"
        return self.result(res,mes)

    cpdef int set_audio_encoder(self, char *codec, int sample_rate, int bit_rate, int channels):
        """
        Set the audio codec
        
        :param codec:           string  codec (string form) used to transmit/receive data 
        to/from the Mediator
        :param sample_rate:     int     sample rate used to transmit/receive data to/from the 
        Mediator
        :param bit_rate:        int     bit rate used to transmit/receive data to/from the 
        Mediator
        :param channels:        int     channels used to transmit/receive data to/from the 
        Mediator
        :return:                S2S_Success if no error occurs
        """

        cdef:
            int res
        res = mcloud_h.mcloudSetAudioEncoder2(self._mcloud, codec, sample_rate,
                                                       bit_rate, channels)
        mes = "Set audio encoder {} {} {} {}".format(str(codec), str(sample_rate),
                                                     str(bit_rate), str(channels))
        return self.result(res, mes)

    cpdef int wait_for_finish(self, int done, queue_type):
        """
        Wait until all pending packages have been processed/ sent. This 
        function can be used to wait until all pending packages have been 
        processed or sent in the queue specified.
        
        :param done:        int   if set to 1, indicates that processing of the request has 
        been completed
        :param queue_type: string if set to "sending", MCloudSendingQueue is used else 
        MCloudProcessingQueue
        :return:      S2S_Success if no error occurs
        """
        cdef:
            mcloud_h.MCloudType queue
            int res
        queue = mcloud_h.MCloudProcessingQueue
        if queue_type == "sending":
            queue = mcloud_h.MCloudSendingQueue

        res = mcloud_h.mcloudWaitFinish(self._mcloud,
                                                <mcloud_h.MCloudType> queue, done)
        mes = "Wait for finish " + queue_type
        return self.result(res, mes)

    cpdef int wait_for_client(self, char* stream):
        """
        Wait for a service request to process. This function has to be called after the worker has been successfully
        connected to the MCloud in order to wait for an incoming service request to process.
        :param stream_id:   string      id of input stream
        :return:            S2S_Success if no error occurs
        """
        cdef:
            int res
            char* stream_id = NULL

        res = mcloud_h.mcloudWaitForClient (self._mcloud, &stream_id)
        mes = "wait for client"
        self.result(res, mes)
        return res

    cpdef int stop_processing(self, queue_type):
        """
        Stop processing, sending pending packages immediately, and reset queue. 
        This function can be used to stop further processing or sending packages
        in the queue specified.
        
        :param queue_type: string if set to "sending", MCloudSendingQueue is used else 
        MCloudProcessingQueue
        :return:    S2S_Success if no error occurs
        
        """
        cdef:
            mcloud_h.MCloudType queue
            int res
        queue = mcloud_h.MCloudProcessingQueue
        if queue_type == "sending":
            queue = mcloud_h.MCloudSendingQueue

        res = mcloud_h.mcloudBreak(self._mcloud, <mcloud_h.MCloudType> queue)
        mes = "break {}".format(queue_type)
        return self.result(res, mes)

    cpdef int send_done(self):
        """
        Inform a client or a worker that there is no more data to receive.
        :return: S2S_Success if no error occurs
        """
        cdef int res = mcloud_h.mcloudSendDone(self._mcloud)
        mes = "Send done"
        return self.result(res, mes)

    cpdef int send_flush(self):
        """
        Inform subsequent worker to flush their output buffers. This function should be called to inform subsequent 
        workers finalize processing data stored in the queue and to flush their buffers.
        :return:    S2S_Success if no error occurs
        """
        cdef int res
        with nogil:
             res = mcloud_h.mcloudSendFlush(self._mcloud)
        mes = "Send flush"
        return self.result(res, mes)

    cpdef int result(self, int res, mes):
        log = "MCLOUD_WRAPPER"
        if res == 0:
            print("{} SUCCESS calling function: {}".format(log, mes))
            return mcloud_h.S2S_Success
        print ("{} ERROR calling function: {}".format(log, mes))

        self.disconnect()
        print("INFO Program interrupted!")
        sys.exit()

    cpdef int pending_packets(self):
        """
        Return number of pending packages in queue.
        """
        return <int> mcloud_h.mcloudPending(self._mcloud, mcloud_h.MCloudProcessingQueue)

    cdef void append_translation(self, char* translation):
        self.translations.append(translation.decode("utf-8", "replace"))
        self.rcv_packet_count += 1
        #printf("%d\n",self.rcv_packet_count)

    cdef void print_translation(self):
        if len(self.translations) == 0:
            return
        else:
            translations_no_dupes = set()
            translations_no_dupes = [x for x in self.translations if x not in translations_no_dupes
                                     and not translations_no_dupes.add(x)]
            trans_len = len(self.translations)
            translation = " ".join(list(translations_no_dupes))
            print(f"TRANSLATIONS FOR Packets 1 till {trans_len}: {translation}")
            # for i, trans in list(enumerate(self.translations)):
            #     print(f"TRANSLATION pkt_no: {i} trans: {trans}")


    def set_callback(self, mode, python_callback, queue_type=None):

        cdef:
            mcloud_h.MCloudType queue
        queue = mcloud_h.MCloudProcessingQueue
        if queue_type == "sending":
            queue = mcloud_h.MCloudSendingQueue
        if mode == "error":
            """
            This function is called as soon as an error occurs in the asynchronous processing.
            """

            mcloud_h.mcloudSetErrorCallback(self._mcloud, queue,  self.py_clb_wrapper, <void*> python_callback)
        elif mode == "break":
            """
            This function is called when the worker should stop the processing as soon as possible.
            """
            mcloud_h.mcloudSetBreakCallback(self._mcloud, queue,  self.py_clb_wrapper, <void*> python_callback)
        elif mode == "init":
            """
            This function is called as soon as an incoming service request has been accepted by the worker, 
            i.e. in mcloudWaitForClient. The packet containing the service description is passed to the init callback
            function as argument.
            """
            mcloud_h.mcloudSetInitCallback(self._mcloud,<mcloud_h.MCloudPacketCallbackFct*>  py_worker_init_clb_wrapper, <void*> python_callback)

            #mcloud_h.mcloudSetInitCallback(self._mcloud, <void*> python_callback, user_data)

        elif mode == "finalize":
            """
            This function is called as soon as the processing of packets should be finalized, i.e. no more 
            packets will follow and the worker should output the final results after all pending packets have 
            been processed..
            """
            mcloud_h.mcloudSetFinalizeCallback(self._mcloud, self.py_clb_wrapper, <void*> python_callback)

    def set_data_callback(self, mode):
        """
        This function is called for each incoming data package in a serial way, i.e.
        after a package has been processed it is called again if more packages are pending.
        Note that for this function no userData is given at the time of the set
        of the callback function. Instead, the userData is given per packet with
        mcloudProcessDataAsync or mcloudSendAsync.
        This callback is available for the processing queue only.
        :param mode     string      "client" or "worker"
        """
        if mode == "client":
            mcloud_h.mcloudSetDataCallback(self._mcloud, <mcloud_h.MCloudPacketCallbackFct*>self.py_client_data_clb_wrapper)
        else:
            mcloud_h.mcloudSetDataCallback(self._mcloud, <mcloud_h.MCloudPacketCallbackFct*> py_worker_data_clb_wrapper)

    @staticmethod
    cdef int py_clb_wrapper(mcloud_h.MCloud* mcloud, void*user_data):
        try:
            global firststart
            firststart = True
            func = <object> user_data
            printf("Call callback func!\n")
            func()
            return 0
        except:
            return -1





    @staticmethod
    cdef int py_client_data_clb_wrapper(mcloud_h.MCloud* mcloud, mcloud_h.MCloudPacket*packet, void*user_data):
        #printf("Data Callback called!")
        cdef:
            char** text = <char**> malloc(sizeof(char*))
            int res
            char* translation
            cdef MCloudWrap mcloud_wrap = <MCloudWrap> user_data

        res = mcloud_h.mcloudPacketGetText(<mcloud_h.MCloud*> mcloud,
                                               <mcloud_h.MCloudPacket*> packet, text)
        translation = (<char*> text[0])
        mcloud_wrap.append_translation(translation)



    @staticmethod
    cdef int py_finalizeCallback (MCloud *cP, void *userData):
        return 0

    @staticmethod
    cdef int py_breakCallback (MCloud *cP, void *userData):
        return 0

    @staticmethod
    cdef int py_errorCallback (MCloud *cP, void *userData):
        return 0


cdef void timePrint (s2stime.S2S_Time *t, char *str) :
    cdef int day = t.day
    cdef int month = t.month
    cdef int year = t.year-2000
    cdef int hour = t.hour
    cdef int minute = t.minute
    cdef int second = t.second
    cdef int milliseconds = t.milliseconds
    sprintf (str,"%02d/%02d/%02d-%02d:%02d:%02d.%d",day, month, year,hour, minute, second,milliseconds)

    return

cdef int py_worker_init_clb_wrapper(mcloud_h.MCloud* mcloud, mcloud_h.MCloudPacket*packet, void*user_data):
    s2stime.s2s_GetSystemTime(&startT_global)
    python_init_callback(function_init_callback,user_data)
    return 0


cdef s2stime.S2S_Time startT_global


cdef int py_worker_data_clb_wrapper(mcloud_h.MCloud* mcloud, mcloud_h.MCloudPacket*packet, void* python_callback) :

        cdef short *sampleA = NULL
        cdef int    sample

        mcloud_h.mcloudPacketGetAudio (mcloud, packet, <short **> &sampleA,<int*> &sample);

        lst=[]

        cdef int j =0

        for j in range(sample):
            lst.append(sampleA[j])
        func = <object> python_callback


        cdef int  startTimeToken
        cdef int  endTimeToken
        cdef  char     startTime[128]
        cdef char stopTime[128]

        startTimeToken, endTimeToken,list_words, length= func(sample,lst)
        #result,startTime,endTime = python_data_callback(callback,sample,sampleA, <void*>python_callback)

        cdef int a = 0

        cdef int i =0

        cdef MCloudWordToken* tokenA = NULL


        if length == 0:
            return 0

        tokenA = mcloudWordTokenArrayCreate (length)






        cdef int mediator_time = startTimeToken
        cdef float duration = endTimeToken - startTimeToken
        for i in range(length):


            tokenA[i].index      = i
            tokenA[i].internal   = strdup(list_words[i].encode("utf-8"))
            tokenA[i].written    = strdup(list_words[i].encode("utf-8"))
            tokenA[i].spoken     = strdup("")
            tokenA[i].confidence =  -1.0
            tokenA[i].startTime  = mediator_time
            tokenA[i].stopTime   = mediator_time + duration/length
            mediator_time =   tokenA[i].stopTime
            tokenA[i].isFiller   = 0


        cdef s2stime.S2S_Time end_token = startT_global
        cdef s2stime.S2S_Time begin_token = startT_global
        s2stime.s2s_AddToTime(&begin_token, startTimeToken, 0)
        s2stime.s2s_AddToTime(&end_token,  endTimeToken, 0)
        timePrint(&begin_token, startTime)
        timePrint(&end_token,  stopTime)
        cdef MCloudPacket* npm = NULL
        npm = <MCloudPacket*> mcloudPacketInitFromWordTokenA (mcloud,startTime,stopTime, startTimeToken, endTimeToken, NULL, tokenA, length)

        #func_write = <object> write_file

        mcloudSendPacketAsync (mcloud, npm, NULL)

        #write_file(npm.xmlString.decode("utf-8"))

        mcloudWordTokenArrayFree (tokenA, length)
        free (sampleA)
        sampleA = NULL


        return 0

cpdef mcloudpacketdenit(MCloudPacketRCV packet):
    mcloudPacketDeinit(<mcloud_h.MCloudPacket*> packet._mcloud_packet)

def write_file(string):
    f = open("xml","a")
    f.write(string+"\n")
    f.close
cdef int parseTime (char *string, s2stime.S2S_Time *t):
    cdef int res
    res = sscanf(string, "%02d/%02d/%02d-%02d:%02d:%02d.%d",&(t.day), &(t.month), &(t.year),&(t.hour), &(t.minute), &(t.second), &(t.milliseconds))



    if (res == 7):
        return 0
    return 0

cdef char * callback(int number,short *sampleA,void *f)  :
    lst=[]
    cdef int i =0
    for i in range(number):
        lst.append(sampleA[i])
    return (<object>f)(number,lst)

cdef char * python_data_callback(datacallback user_func,int number,short *sampleA,void *user_data)  :

    return user_func(number,sampleA,user_data)

cdef void python_init_callback(init_callback user_func,void *user_data)  :
    user_func(user_data)

cdef void  function_init_callback(void *f)  :
    (<object>f)()

