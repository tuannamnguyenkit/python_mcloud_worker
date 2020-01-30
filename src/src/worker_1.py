from MCloud import *
from S2STime import *
from WorkerUserData import *
import subprocess
from MCloudPacketRCV import MCloudPacketRCV
import os
import torch
import numpy as np

import time

TEMP_DIR = "/tmp/recognizer"
TEMP_FILE = "/tmp/transcript/result.txt"

def printusage():
    print("\n")
    print("\nNAME\n\t%s - Speech Recognition Backend.\n");
    print("\nSYNOPSIS\n\t%s [OPTION]... ASRCONFIGFILE\n");
    print("\nDESCRIPTION\n""\tThis is a example implementation of an ASR backend which connects to""\tMTEC's Mediator in the cloud.\n");
    print("\nOPTION\n""\t-s, --server=HOSTNAME\n\t\tHost name of the server where the Mediator is running.\n\n""\t-p, --serverPort=PORT\n\t\tPort address at which the Mediator accepts worker.\n\n""\t-h, --help\n\t\tShows this help.\n\n")
    return 0
def processing_finalize_callback():
    print("INFO in processing finalize callback")
    global proc
    proc.stdin.close()
    proc.terminate()


def processing_error_callback():
    print("INFO In processing error callback")
    global proc
    proc.stdin.close()
    proc.terminate()


def processing_break_callback():
    print("INFO in processing break callback")
    global proc
    proc.stdin.close()
    proc.terminate()


def init_callback():
    clean(tempDir)
    global proc
    args = "-audio %s/recording.adc -tmpDir %s -file -"
    path = os.path.dirname(os.path.realpath(__file__))
    segmenter = path + "/segmenter"
    params = (args % (TEMP_DIR, TEMP_DIR)).split()
    params.insert(0, segmenter)

    proc = subprocess.Popen(params,
                            universal_newlines=False,
                              stdin=subprocess.PIPE)
    print("INFO in processing init callback ")


def data_callback(i,sampleA):

    sample = np.asarray(sampleA,dtype=np.int16)
    print(len(sample))
    global proc
    proc.stdin.write(sample.tobytes())
    line = ""
    if os.path.exists(TEMP_DIR+"/result.txt"):

        f =open(TEMP_DIR+"/result.txt","r")
        result = f.read().strip()
        result=result.replace("<unk>",""  )
        f.close()
        line = result
        print(result)
        os.remove(TEMP_DIR+"/result.txt")
    return line.encode("utf-8")

def clean(tempDir):
    if os.path.exists(tempDir):
        subprocess.call(["rm -rf %s/*" % tempDir], shell=True)
    else:
        os.mkdir(tempDir)
serverHost = "i13srv53"
serverPort = 60019
inputFingerPrint  = "en-TF"
inputType         = "audio"
outputFingerPrint = "en-TF"
outputType        = "unseg-text"
star_time         = ""
specifier           = ""
stream_id = ""
tempDir = TEMP_DIR
print("#" * 40 + " >> TESTING MCLOUD WRAPPER API << " + "#" * 40)

mcloud_w = MCloudWrap("asr".encode("utf-8"), 1)

user_data  = WorkerUserData(mcloud_w,star_time.encode("utf-8"))
mcloud_w.add_service("MTEC asr".encode("utf-8"), "asr".encode("utf-8"), inputFingerPrint.encode("utf-8"), inputType.encode("utf-8"),outputFingerPrint.encode("utf-8"), outputType.encode("utf-8"), specifier.encode("utf-8"))
#set callback
mcloud_w.set_callback("init", init_callback)
mcloud_w.set_data_callback("worker")
mcloud_w.set_callback("finalize", processing_finalize_callback)
mcloud_w.set_callback("error", processing_error_callback)
mcloud_w.set_callback("break", processing_break_callback)
#clean tempfile
if os.path.exists(tempDir):
    subprocess.call(["rm -rf %s/*" % tempDir], shell=True)
else:
    os.mkdir(tempDir)

global proc

while True:
    err = 0
    #connect to mediator
    res = mcloud_w.connect(serverHost.encode("utf-8"), serverPort)
    i = 0
    if res == 1:
        time.sleep(1.0)
        continue
    else:
        print("WORKER INFO Connection established ==> waiting for clients.")
    while True:
        #wait for client
        res = mcloud_w.wait_for_client(stream_id.encode("utf-8"))

        proceed = False
        if res == 1:
            print("WORKER ERROR while waiting for client")
            break
        elif res ==0 :

            proceed = True
            print("WORKER INFO received client request ==> waiting for packages")
        while (proceed):

            packet = MCloudPacketRCV(mcloud_w)


            type  = packet.packet_type()
            if  packet.packet_type() == 3:


                mcloud_w.process_data_async(packet,data_callback)

            elif packet.packet_type() == 7:  # MCloudFlush
                """
                a flush message has been received -> wait (block) until all pending packages
                from the processing queue has been processed -> finalizeCallback will
                be called-> flush message will be passed to subsequent components
                """
                mcloud_w.wait_for_finish(0, "processing")
                mcloud_w.send_flush()
                print("WORKER INFO received flush message ==> waiting for packages.")
                mcloudpacketdenit(packet)
                break
            elif packet.packet_type() == 4:  # MCloudDone


                print("WOKRER INFO received DONE message ==> waiting for clients.")
                mcloud_w.wait_for_finish(1, "processing")
                mcloudpacketdenit(packet)
                clean(tempDir)
                proceed = False
            elif packet.packet_type() == 5:  # MCloudError
                # In case of a error or reset message, the processing is stopped immediately by
                # calling mcloudBreak followed by exiting the thread.

                mcloud_w.stop_processing("processing")
                mcloudpacketdenit(packet)
                clean(tempDir)
                print("WORKER INFO received ERROR message >>> waiting for clients.")
                proceed = False
            elif packet.packet_type() == 6:  # MCloudReset
                mcloud_w.stop_processing("processing")

                print("CLIENT INFO received RESET message >>> waiting for clients.")
                mcloudpacketdenit(packet)
                clean(tempDir)
                proceed = False
            else:
                print("CLIENT ERROR unknown packet type {!s}".format(packet.packet_type()))
                proceed = False
                err = 1
            if err == 1:
                break
        print("WORKER WARN connection terminated ==> trying to reconnect.")