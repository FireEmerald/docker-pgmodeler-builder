# syntax=docker/dockerfile:1

# Debug via docker run --name test -it <hash> bash -il

# Dockerfile-cc
FROM ubuntu:23.04 AS cc

RUN apt-get update && \
  apt-get install -y autoconf automake autopoint bash bison bzip2 flex g++ g++-multilib gettext git gperf intltool \
  libc6-dev-i386 libgdk-pixbuf2.0-dev libltdl-dev libgl-dev libssl-dev libtool-bin libxml-parser-perl lzip make openssl \
  p7zip-full patch perl python3 python3-mako python3-pkg-resources ruby sed unzip wget xz-utils && \
  apt-get install -y python-is-python3
# python-is-python3 is required because by default none python is found (even if installed)

RUN cd /opt && \
  git clone https://github.com/mxe/mxe.git && \
  cd mxe && \
  make MXE_TARGETS='x86_64-w64-mingw32.shared x86_64-w64-mingw32.static' cc


# Dockerfile-deps1
FROM cc AS deps1

# freetype(indirect) needs those in the step after
RUN apt-get install -y libpcre3-dev

RUN cd /opt/mxe && \
  make MXE_TARGETS='x86_64-w64-mingw32.shared x86_64-w64-mingw32.static' zlib && \
  make MXE_TARGETS='x86_64-w64-mingw32.shared' cc dbus openssl pcre2 fontconfig freetype harfbuzz jpeg libpng zlib zstd \
    sqlite mesa postgresql libxml2 && \
  mkdir -p /opt/src && \
  cd /opt/src && \
  git clone https://github.com/digitalist/pydeployqt.git


# Dockerfile-deps2
FROM deps1 AS deps2

RUN cd /opt/mxe && \
  make MXE_TARGETS='x86_64-w64-mingw32.shared' qt6-qtbase qt6-qtimageformats qt6-qtsvg && \
  rm -rf pkg .ccache


# Dockerfile-postgres
FROM deps2 AS pg

ARG VERSION_POSTGRESQL=REL_15_2

RUN cd /opt/src && \
  git clone https://github.com/postgres/postgres.git && \
  cd postgres && \
  git checkout -b ${VERSION_POSTGRESQL} ${VERSION_POSTGRESQL} && \
  cd /opt/src/postgres && \
  PATH=/opt/mxe/usr/bin:${PATH} ./configure --host=x86_64-w64-mingw32.static --prefix=/opt/postgresql && \
  PATH=/opt/mxe/usr/bin:${PATH} make && \
  PATH=/opt/mxe/usr/bin:${PATH} make install && \
  cd /opt/src && \
  rm -rf postgres


# Dockerfile
FROM pg AS main

# temporary here for debug, should be moved up perhaps later
RUN apt-get update && \
  apt-get install -y vim qt6-declarative-dev libqt6svg6-dev libxext-dev

COPY data /

# temporary here for debug, should be removed
RUN chmod +x /opt/src/script/build.sh

WORKDIR /opt
#ENTRYPOINT ["/bin/bash", "src/script/build.sh"]
