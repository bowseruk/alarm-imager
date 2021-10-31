ARG VERSION=latest
FROM archlinux:$VERSION

ENV BOARD=Raspberry_Pi_4 ARCH=ARM64 IMAGE_SIZE=8000

RUN pacman -Syu wget base base-devel dosfstools linux-api-headers parted python-setuptools arm-none-eabi-gdb arm-none-eabi-newlib arm-none-eabi-binutils arm-none-eabi-gcc dtc git swig uboot-tools --noconfirm

RUN mkdir -p /app /data/alarm-imager

ADD https://raw.githubusercontent.com/bowseruk/ALARM-Imager/main/build-image-root.sh /app/build-image-root.sh

RUN chmod u+x /app/build-image-root.sh

WORKDIR /app

CMD ./build-image-root.sh -m Image -d /data/alarm-imager/ -b $BOARD -a $ARCH -s $IMAGE_SIZE
