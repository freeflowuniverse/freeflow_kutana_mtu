FROM ubuntu:18.04 as builder

RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y \
    build-essential \
    libmicrohttpd-dev \
    libjansson-dev \
    libnice-dev \
    libssl-dev \
    libsofia-sip-ua-dev \
    libglib2.0-dev \
    libopus-dev \
    libogg-dev \
    libini-config-dev \
    libcollection-dev \
    libconfig-dev \
    libsrtp-dev \
    pkg-config \
    gengetopt \
    libtool \
    autotools-dev \
    automake \
    gtk-doc-tools \
    sudo \
    make \
    git \
    graphviz \
    cmake \
    wget \
    nginx \
    curl

RUN curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -

RUN apt install -y nodejs

RUN cd / \
    && wget https://github.com/cisco/libsrtp/archive/v2.1.0.tar.gz \
    && tar xfv v2.1.0.tar.gz \
    && cd libsrtp-2.1.0 \
    && ./configure --prefix=/usr --enable-openssl \
    && make shared_library && sudo make install

RUN cd / \
    && git clone https://github.com/sctplab/usrsctp \
    && cd usrsctp \
    && ./bootstrap \
    && ./configure --prefix=/usr \
    && make \
    && sudo make install

RUN cd / \
    && git clone https://github.com/warmcat/libwebsockets.git \
    && cd libwebsockets \
    && git checkout v2.1.0 \
    && mkdir build \
    && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr .. \
    && make \
    && sudo make install

RUN cd / \ 
    && git clone https://gitlab.freedesktop.org/libnice/libnice \
    && cd libnice \
    && ./autogen.sh \
    && ./configure --prefix=/usr \
    && make && sudo make install

COPY . /janus-gateway/
COPY .git/ /.git
WORKDIR /janus-gateway/
RUN ./autogen.sh
RUN ./configure --prefix=/opt/janus --enable-javascript-es-module --disable-unix-sockets --disable-rabbitmq --disable-mqtt --disable-plugin-audiobridge --disable-data-channels --disable-plugin-echotest --disable-plugin-recordplay --disable-plugin-sip --disable-plugin-sipre --disable-plugin-nosip --disable-plugin-textroom --disable-plugin-videocall --disable-plugin-voicemail
RUN make CFLAGS='-std=c99'
RUN make install

FROM ubuntu:18.04

RUN apt-get update -y \
    && apt-get upgrade -y
RUN apt-get update --fix-missing -y
RUN apt-get install -y \
    build-essential \
    libmicrohttpd-dev \
    libjansson-dev \
    libnice-dev \
    libssl-dev \
    libsofia-sip-ua-dev \
    libglib2.0-dev \
    libopus-dev \
    libogg-dev \
    libini-config-dev \
    libcollection-dev \
    libconfig-dev \
    libsrtp-dev \
    pkg-config \
    gengetopt \
    libtool \
    autotools-dev \
    automake \
    gtk-doc-tools \
    sudo \
    make \
    git \
    graphviz \
    cmake \
    wget \
    nginx

COPY ./plugins /opt/janus/lib/janus/plugins
COPY --from=builder /janus-gateway/plugins /opt/janus/lib/janus/plugins
COPY --from=builder /janus-gateway/transports /opt/janus/lib/janus/transports
RUN cp -r /opt/janus/lib/janus/plugins/.libs/*.s* /opt/janus/lib/janus/plugins/
RUN cp -r /opt/janus/lib/janus/transports/.libs/*.s* /opt/janus/lib/janus/transports/

RUN cd / \
    && git clone https://github.com/warmcat/libwebsockets.git \
    && cd libwebsockets \
    && git checkout v2.1.0 \
    && mkdir build \
    && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr .. \
    && make \
    && sudo make install

RUN mkdir -p /opt/janus/bin/

COPY --from=builder /janus-gateway/janus /opt/janus/bin/

RUN mkdir libs
COPY --from=builder /usrsctp libs/usrsctp
COPY --from=builder /libsrtp-2.1.0 libs/libsrtp-2.1.0
COPY --from=builder /usr/lib/cmake/libwebsockets /usr/lib/cmake/libwebsockets
COPY --from=builder /libnice libs/libnice
COPY ./certs/* /opt/janus/share/janus/localcerts/
COPY ./certs/* /opt/janus/share/janus/certs/
COPY ./certs /certs
RUN cd libs/usrsctp && make install
RUN cd libs/libsrtp-2.1.0 && make install
RUN cd libs/libnice && make install

COPY ./configs/* /opt/janus/etc/janus/
COPY ./html/* /janus-gateway/html/
# COPY nginx.conf /etc/nginx/nginx.conf
# COPY testfile.txt /opt/nginx/testfile.txt

# COPY conf/stun.cfg /opt/janus/stun.cfg
CMD  /opt/janus/bin/janus
