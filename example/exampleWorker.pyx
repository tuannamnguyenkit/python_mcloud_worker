from libc.stdio cimport FILE
from time import sleep
from WorkerUserData cimport WorkerUserData
from MCloudPacketRCV cimport MCloudPacketRCV
from MCloud cimport MCloudWrap
cimport MCloud as mc
cimport exampleWorker


def processing_finalize_callback():
    print("INFO in processing finalize callback")

def processing_error_callback():
    print("INFO In processing error callback")

def processing_break_callback():
    print("INFO in processing break callback")

def init_callback():
    print("INFO in processing break callback")

cpdef run():

    """
    This method aims to achieve same functionality like "ExampleClientBiDir.c" from PerVoice
    """
    print("#" * 40 + " >> TESTING MCLOUD WRAPPER API << " + "#" * 40)

    cdef:
        char* server_host = "i13srv30.ira.uka.de"
        int server_port = 4443
        const char *input_finger_print  = "any-binary"
        const char *input_type         = "binary"
        const char *output_finger_print = "null-binary"
        const char *output_type        = "binary"
        const char *output_dir         = "."
        MCloudWrap mcloud_w
        WorkerUserData user_data
        int err = 0
        int res
        MCloudPacketRCV packet
        char* stream_id = NULL

    mcloud_w = mc.MCloudWrap("CythonExampleWorker".encode("utf-8"), mc.MCloudModeWorker)
    user_data  = WorkerUserData(mcloud_w, output_dir)
    mcloud_w.add_service("PerVoice bin-worker", "binary-dump", input_finger_print, input_type,
                         output_finger_print, output_type, NULL)
    mcloud_w.set_callback("init", init_callback, user_data)
    mcloud_w.set_data_callback(mode="worker")
    mcloud_w.set_callback("finalize", processing_finalize_callback, "processing")
    mcloud_w.set_callback("error", processing_error_callback, "processing")
    mcloud_w.set_callback("break", processing_break_callback, "processing")
    halt = False
    while True:
        err = 0
        res = mcloud_w.connect(server_host, server_port)
        if res == 1:
            sleep(0.2)
        else:
            print("WORKER INFO Connection established ==> waiting for clients.")

        while True:
            res = mcloud_w.wait_for_client(stream_id)
            if res == 1:
                print("WORKER ERROR while waiting for client")
                break
            else:
                print("WORKER INFO received client request ==> waiting for packages")

            while True:

                packet = MCloudPacketRCV(<MCloudWrap> mcloud_w, halt)
                if packet._mcloud_packet is NULL:
                    print("WORKER ERROR while waiting for messages")
                    err = 1
                    break

                if not halt:
                    packet_type = <int> packet.packet_type
                    #print("CLIENT INFO {}. iteration of receiving loop.".format(i))
                    #print("MCLOUD_PACKET_RCV Current packet type: " + str(packet_type))
                    #print("MCLOUD_PACKET_RCV XML String: {}".format(str(p.xml_string)))
                    if packet_type == mc.MCloudData:  # MCloudData
                        #packet.get_text()
                        mcloud_w.process_data_async(<MCloudPacketRCV> packet, mcloud_w)
                        halt = False
                        break
                    elif packet_type == mc.MCloudFlush:  # MCloudFlush
                        """
                        a flush message has been received -> wait (block) until all pending packages
                        from the processing queue has been processed -> finalizeCallback will
                        be called-> flush message will be passed to subsequent components
                        """
                        mcloud_w.wait_for_finish(0, "processing")
                        mcloud_w.send_flush()
                        print("WORKER INFO received DONE message ==> waiting for packages.")
                        halt = False
                        break
                    elif packet_type == mc.MCloudDone:  # MCloudDone
                        """
                        a done message has been received -> wait (block) until all pending packages 
                        from the processing queue has been processed -> finalizeCallback will
                        called-> (send done) 
                        """
                        print("WOKRER INFO received DONE message ==> waiting for clients.")
                        mcloud_w.wait_for_finish(1, "processing")
                        halt = True
                    elif packet_type == mc.MCloudError:  # MCloudError
                        # In case of a error or reset message, the processing is stopped immediately by
                        # calling mcloudBreak followed by exiting the thread.
                        mcloud_w.stop_processing("processing")
                        print("WORKER INFO received ERROR message >>> waiting for clients.")
                        halt = True
                    elif packet_type == mc.MCloudReset:  # MCloudReset
                        mcloud_w.stop_processing("processing")
                        print("CLIENT INFO received RESET message >>> waiting for clients.")
                        halt = True
                    else:
                        print("CLIENT ERROR unknown packet type {!s}".format(packet.packet_type))
                        halt = True
                        err = 1

                if err == 1:
                    break

            print("WORKER WARN connection terminated ==> trying to reconnect.")








