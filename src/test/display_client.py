#!/usr/bin/env python
# -*- coding: utf-8 -*-

import socket
import struct
import xml.etree.ElementTree as ET
from threading import Thread


class DisClient():

    def __init__(self):
        self.socket = None
        self.running = True
        self.t = None

    def connect(self):
        self.t = Thread(target=self._connect)
        self.t.daemon = True
        self.t.start()
        print("CONNECTED")

    def close(self):
        self.running = False
        try:
            self.socket.shutdown(socket.SHUT_RDWR)
            self.socket.close()
        except:
            pass

    def sendXML(self, xmlString):
        self.sendString(xmlString.encode("utf-8"))

    def sendString(self, msg):
        print(">>> " + msg)
        prefix = struct.pack("<L", socket.htonl(len(msg)))
        try:
            self.socket.sendall(prefix + msg)
        except:
            self.close()

    def _connect(self):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect(("i13srv30.ira.uka.de", 4443))
        print(self.socket.getsockname())
        print(socket.getfqdn())
        self._receive()

    def _receive(self):
        msg_len = 4
        msg = ""
        state = 0
        while self.running:
            try:
                chunk = self.socket.recv(msg_len)
            except:
                chunk = ""
            if not chunk:
                self.close()
                return
            if state == 0:
                # get msg length, 4 byte, unsigned long, big endian.
                msg_len = struct.unpack(">L", chunk)[0]
                state = 1
            else:
                msg_len -= len(chunk)
                msg += chunk
                if msg_len == 0:
                    msg_len = 4
                    state = 0
                    self._handle_msg(msg)
                    msg = ""

    def _handle_msg(self, msg):
        print ("<<< " + msg)
        el = ET.fromstring(msg)
        if el.tag == "session":
            msgtype = el.get("type")
            if msgtype == "add":
                sessionid = int(el.get("sessionid"))
                streams_el = el.find("streams").findall("stream")
                for stream_el in streams_el:
                    fingerprint = stream_el.get("fingerprint")
                    displayname = stream_el.get("displayname")
                    streamid = stream_el.get("streamid")
                    control = stream_el.get("control")
                    type = stream_el.get("type")
                    if fingerprint == "en":
                        self._subscribe(sessionid, streamid, fingerprint,
                                        displayname, control, type)
            elif msgtype == "delete":
                pass
        elif el.tag == "data":
            pass

    def _subscribe(self, session_id, streamid, fingerprint, displayname,
                   control, type):
        xmlString = '<register type="add" sessionid="{}"><streams><stream streamid="{}" fingerprint="{}" displayname="{}" control="{}" type="{}"/></streams></register>'.format(
            session_id, streamid, fingerprint, displayname, control, type)
        print (xmlString)
        self.sendXML(xmlString)

    def _unsubscribe(self, session_id, streamid, fingerprint, displayname,
                     control, type):
        xmlString = '<register type="delete" sessionid="{}"><streams><stream streamid="{}" fingerprint="{}" displayname="{}" control="{}" type="{}"/></streams></register>'.format(
            session_id, streamid, fingerprint, displayname, control, type)
        self.sendXML(xmlString)


if __name__ == "__main__":
    rc = DisClient()
    rc.connect()
    rc.t.join(99999)
    rc.close()
