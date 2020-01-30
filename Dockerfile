FROM python:3.7

RUN \
  apt-get update && \
  apt-get upgrade  

COPY requirements.txt  /home/isl_mcloud_wrapper/
WORKDIR /home/isl_mcloud_wrapper
RUN pip3 install -r requirements.txt
WORKDIR /
COPY src /home/isl_mcloud_wrapper/src
COPY README.md /home/isl_mcloud_wrapper/
COPY audio /home/isl_mcloud_wrapper/audio

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/isl_mcloud_wrapper/src/linux_lib64
WORKDIR /home/isl_mcloud_wrapper/src/
RUN python3 setup.py build_ext --inplace
WORKDIR /home/isl_mcloud_wrapper/src/src
CMD /bin/bash

