# cython: language_level=3
import socket
import signal
import time as t
import threading
import sys
from datetime import datetime

from libc.stdio cimport FILE, fopen, fclose, feof, fread, printf
from libc.stdlib cimport malloc, free, realloc
from posix.unistd cimport usleep

cimport MCloud as mc
cimport S2STime as s2stime
from MCloudPacketSND cimport MCloudPacketSND
from MCloudPacketRCV cimport MCloudPacketRCV
from UserData cimport UserData
from S2STime cimport PyS2STime, py_time_print, py_time_init, py_add_to_time, py_cmp_time, py_time_duration

#sys.stdout = open("output.txt", "w")

def signal_handler(sig, frame):
    print("\nCLIENT INFO You pressed CTRL+Z!")
    for obj in mc.MCloudWrap.get_instances():
        obj.disconnect()
        print("CLIENT INFO Shutting Client down... Bye!")
        sys.exit()

signal.signal(signal.SIGTSTP, signal_handler)

cdef _recv_message_main(UserData user_data, processing_callback_func):
    cdef:
        mc.MCloudWrap mcloud_w = <mc.MCloudWrap> user_data.mcloud
        MCloudPacketRCV packet
        int packet_type
        int i = 1
        bint true = True
        bint halt = False


    #print("CLIENT INFO Receiving thread started!")
    while true:

        packet = MCloudPacketRCV(<mc.MCloudWrap> mcloud_w, halt)
        if packet._mcloud_packet is NULL:
            printf("CLIENT INFO Receiving thread break!")
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
            elif packet_type == mc.MCloudFlush:  # MCloudFlush
                halt = False
            elif packet_type == mc.MCloudDone:  # MCloudDone
                # In case of a done message, mcloudWaitFinish is called in order to wait until
                # the processing of all pending packets in the processing queue has finished,
                # directly followed by leaving this thread
                printf("CLIENT INFO received DONE message >>> end thread.")
                mcloud_w.wait_for_finish(1, "processing")
                user_data.proceed = 0
                print("USER_DATA {!s} proceed set to {!s}.".format(user_data, user_data.proceed))
                halt = True
            elif packet_type == mc.MCloudError:  # MCloudError
                # In case of a error or reset message, the processing is stopped immediately by
                # calling mcloudBreak followed by exiting the thread.
                mcloud_w.stop_processing("processing")
                printf("CLIENT INFO received ERROR message >>> end thread.")
                user_data.proceed = 0
                halt = True
            elif packet_type == mc.MCloudReset:  # MCloudReset
                mcloud_w.stop_processing("processing")
                printf("CLIENT INFO received RESET message >>> end thread.")
                user_data.proceed = 0
                halt = True
            else:
                print("CLIENT ERROR unknown packet type {!s}".format(packet.packet_type))
                user_data.proceed = 0
        i = i + 1

cpdef recv_message(UserData user_data):
    t = threading.Thread(target=_recv_message_main, args=(user_data, processing_data_callback))
    t.daemon = True
    t.start()

# Custom callback functions
def processing_finalize_callback():
    print("INFO in processing finalize callback")

def processing_error_callback():
    print("INFO In processing error callback")

def processing_break_callback():
    print("INFO in processing break callback")

def sending_error_callback():
    print("INFO In sending error callback")

def sending_break_callback():
    print("INFO in sending break callback")

def processing_data_callback(text=""):
    print("CLIENT {}".format(text))

# prototype, ugly
def change_format(time):
    time = list(time.decode("utf8", "strict"))
    time[2] = "/"
    time[5] = "/"
    time[10] = "-"
    time[12] = str(int(time[12]) + 1)
    time = "".join(time).encode("utf8", "strict")
    return time

cpdef run():
    """
    This method aims to achieve same functionality like "ExampleClientBiDir.c" from PerVoice
    """
    print("#" * 40 + " >> TESTING MCLOUD WRAPPER API << " + "#" * 40)

    cdef:
        mc.MCloudWrap mcloud_w
        UserData user_data
        MCloudPacketSND packet_snd
        PyS2STime time
        PyS2STime start_t
        PyS2STime stop_t
        char*fingerprint = "en-EU"
        char*stream_id = "speech"
        char*audio_name = "../../audio/talk1313.mp4-16kHz.wav"
        char*buffer = NULL
        char*riff = "RIFF"
        char*a_codec = "RPCM"
        FILE*audio_file
        int pos = 0
        int sample_rate = 16000
        int chunk_size = <int> (0.128 * sample_rate)
        int buffer_size = 0
        int sample_n = 0
        int eof
        int i = 0
        int zero = 0
        int a_channels = 1
        int a_sample_rate = 16000
        int a_bit_rate = 32000
        unsigned int delta
        unsigned int to_add
        bint true = True
        bytes start_time
        bytes stop_time

    py_time_init()
    print("CLIENT INFO File to send: {} .".format(audio_name.decode()))
    print("CLIENT INFO Processing audio file.")
    audio_file = fopen(audio_name, "rb")
    if audio_file is NULL:
        raise FileNotFoundError(2, "CLIENT INFO No such file or directory: '{}'".format(audio_name))
    while true:
        if feof(audio_file) == 1:
            print("CLIENT INFO End of file reached!")
            print("CLIENT INFO final pos: {!s}\tfinal buffer_size: {!s}".format(pos, buffer_size))
            break
        if (pos + chunk_size) > buffer_size:
            buffer = <char*> realloc(<char*> buffer, (buffer_size + chunk_size) * sizeof(char))
            buffer_size += chunk_size
        pos += fread(buffer + pos, sizeof(char), <int> chunk_size, <FILE*> audio_file)
    sample_n = pos
    pos = 0
    buffer_wave = (<int*> buffer)[0]
    riff_wave = (<int*> riff)[0]
    if buffer_wave == riff_wave:
        print("CLIENT INFO Skipping .wav header.")
        pos += 44
    fclose(audio_file)
    print("CLIENT INFO Finished processing audio file.")
    print("-" * 90)
    mcloud_w = mc.MCloudWrap("CythonDisplayClient".encode("utf-8"), mc.MCloudModeClient)
    print("-" * 90)
    mcloud_w.set_audio_encoder(a_codec, a_sample_rate, a_bit_rate, a_channels)
    print("-" * 90)
    mcloud_w.add_flow_description("en-EU", "TestSessionCython",
                                  "")
    print("-" * 90)
    mcloud_w.connect("i13srv30.ira.uka.de", 4443)  #30 oder 53
    print("-" * 90)
    mcloud_w.announce_output_stream("audio", fingerprint, stream_id,
                                    "Siyar Yikmis")
    print("-" * 90)
    mcloud_w.request_for_display()
    print("-" * 90)
    user_data = UserData(mcloud_w)
    print("USER_DATA created: {!s}".format(user_data))
    print("CLIENT INFO Setting callbacks for sending & processing data")
    mcloud_w.set_data_callback("client")
    mcloud_w.set_callback("finalize", processing_finalize_callback, "processing")
    mcloud_w.set_callback("error", sending_error_callback, "sending")
    mcloud_w.set_callback("break", sending_break_callback, "sending")
    print("-" * 90)
    mcloud_w.request_input_stream("text", "en", stream_id)
    print("-" * 90)
    mcloud_w.set_callback("error", processing_error_callback, "processing")
    mcloud_w.set_callback("break", processing_break_callback, "processing")
    recv_message(<UserData> user_data)
    print("CLIENT INFO Request for input stream accepted >>> sending audio packages.")
    print("-" * 90)
    print("CLIENT INFO Start sending audio packages.")
    time = PyS2STime()
    start_time = py_time_print(<s2stime.S2S_Time*> time._time)
    print("CLIENT INFO Start time sending packets: {}".format(start_time.decode("utf-8", "strict")))
    start_t = PyS2STime()
    audio = open(audio_name.decode(), 'rb')
    now = datetime.now()
    bytes = audio.read(44)
    bytes = audio.read(chunk_size)
    seconds = 0
    print("Chunksize: {!s}".format(chunk_size))
    #while pos + chunk_size < sample_n:
    while len(bytes) == chunk_size:
        # Constructing new packet and sending
        to_add = <unsigned int> ((<float> chunk_size / <float> sample_rate) * 1000.0)
        time._time = <s2stime.S2S_Time*> py_add_to_time(<s2stime.S2S_Time*> time._time,
                                                        <unsigned int> to_add, zero)
        stop_time = py_time_print(<s2stime.S2S_Time*> time._time)
        #printf("%s\n",stop_time)
        packet_snd = MCloudPacketSND(mcloud_w, change_format(start_time), change_format(stop_time),
                                     fingerprint, audio_name, bytes, len(bytes), 0)
        mcloud_w.send_packet(packet_snd)
        pos += chunk_size
        bytes = audio.read(chunk_size)
        i = i + 1
        start_time = py_time_print(<s2stime.S2S_Time*> time._time)

        delta = <unsigned int> (<float> chunk_size / <float> sample_rate * 1000.0) * 1000
        i = 2
        with nogil:
            #printf("Client Gil released!\n")
            usleep(delta)
            pass
        #t.sleep(0.256)
        if i % 100 == 0:
            print(f"CLIENT INFO NO packets send {i}")
            mcloud_w.print_translation()
            # print(">" * 10)
            # print("CLIENT INFO Sending {}. packet pointing to position {!s}".format(i, pos))
            # print("CLIENT INFO Current sleep(",delta,")")
            # print("CLIENT INFO Stop Time: {}".format(stop_time.decode("utf-8", "strict")))
            # print("CLIENT INFO Packet to send XML string: {}".format(str(packet_snd.xml_string)))
            # print("CLIENT INFO Start time following packet: {}".format(start_time.decode("utf-8", "strict")))

    #if sample_n-pos != 0:
    if len(bytes) != chunk_size:
        print(">" * 10)
        str = "CLIENT INFO Sending last packet w/ {!s} bytes (no. {}) with pointing to position {!s}!"
        print(str.format(len(bytes), i, pos + (sample_n - pos)))
        to_add = <unsigned int> ((<float> (sample_n - pos) / <float> sample_rate) * 1000.0)
        time._time = <s2stime.S2S_Time*> py_add_to_time(<s2stime.S2S_Time*> time._time,
                                                        <unsigned int> to_add, 0)
        stop_time = py_time_print(<s2stime.S2S_Time*> time._time)
        # print("CLIENT INFO Stop Time: {}".format(stop_time.decode("utf-8", "strict")))
        packet_snd = MCloudPacketSND(mcloud_w, change_format(start_time), change_format(stop_time),
                                     fingerprint, audio_name, bytes, len(bytes), 1)
        # print("CLIENT INFO Packet to send XML string: {}".format(str(packet_snd.xml_string)))
        mcloud_w.send_packet(packet_snd)
        mcloud_w.send_done()
    print("-" * 90)
    mcloud_w.wait_for_finish(1, "sending")
    print("CLIENT INFO Waiting for worker to finish.")
    print("-" * 90)
    i = 0
    while true:
        if i > 50:
            # If nothing happens at all -> break
            print("CLIENT INFO No packets have been received! >>> Disconnecting from mediator!")
            break
        elif user_data.proceed == 1:
            i += 1
            print("CLIENT Info Worker still working :D")
            t.sleep(10)
        else:
            stop_t = PyS2STime()
            start_time = py_time_print(<s2stime.S2S_Time*> start_t._time)
            stop_time = py_time_print(<s2stime.S2S_Time*> stop_t._time)

            diff = py_time_duration(<s2stime.S2S_Time*> start_t._time, <s2stime.S2S_Time*> stop_t._time, ) / 1000.0
            print("CLIENT INFO DONE: {} to {} - > duration {!s} sec".format(
                start_time.decode("utf-8", "strict"),
                stop_time.decode("utf-8", "strict"),
                diff))
            break
    mcloud_w.disconnect()
    sys.exit()
