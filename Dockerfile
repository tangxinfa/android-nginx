FROM ubuntu:18.04

RUN sed -i 's/http:\/\/archive\.ubuntu\.com\/ubuntu\//http:\/\/mirrors\.163\.com\/ubuntu\//g' /etc/apt/sources.list
RUN apt-get -y update
RUN apt-get install -y make wget cmake git autoconf automake libtool file
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata
RUN mkdir -p /root/android-nginx/build && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone
RUN apt-get install -y android-tools-adb
RUN apt-get install -y unzip
RUN apt-get install -y openssh-client
RUN echo no | dpkg-reconfigure dash
RUN apt-get install -y python
COPY ndk.env /root/android-nginx/
COPY cross-execute /root/android-nginx/
COPY Makefile /root/android-nginx/

WORKDIR /root/android-nginx

ENTRYPOINT ["make"]
