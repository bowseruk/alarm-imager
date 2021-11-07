ARG VERSION=latest
FROM ubuntu:$VERSION

ENV BOARD=Raspberry_Pi_4 ARCH=ARM64 IMAGE_SIZE=8000

ARG DEBIAN_FRONTEND="non-interactive" TZ="Europe/London"

RUN apt-get update && apt-get upgrade -y && apt-get install -y build-essential bison flex libgmp3-dev libmpc-dev libmpfr-dev texinfo libisl-dev dosfstools parted python3-venv python3-pip device-tree-compiler git swig u-boot-tools gcc-arm-none-eabi openssl libssl-dev libarchive-tools wget

RUN mkdir -p /app /data/alarm-imager

ADD https://raw.githubusercontent.com/bowseruk/alarm-imager/main/alarm-imager.sh /app/alarm-imager.sh

RUN chmod u+x /app/build-image-root.sh

WORKDIR /app

CMD ./alarm-imager.sh -m Image -d /data/alarm-imager/ -b $BOARD -a $ARCH -s $IMAGE_SIZE
