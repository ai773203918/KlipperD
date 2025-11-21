FROM debian:12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    systemd systemd-sysv sudo git nano python3 ca-certificates expect nginx virtualenv pkg-config curl wget unzip \
    build-essential gcc-avr binutils-avr avr-libc gcc-arm-none-eabi binutils-arm-none-eabi libnewlib-arm-none-eabi avrdude stm32flash dfu-util \
    python3-dev libffi-dev python3-libgpiod \
    libusb-dev libusb-1.0-0-dev libjpeg-dev libopenjp2-7 libsodium-dev liblmdb-dev libncurses-dev \
    packagekit wireless-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    update-ca-certificates

STOPSIGNAL SIGRTMIN+3


WORKDIR /home/zwzw

COPY klipper_install.sh /home/zwzw/klipper_install.sh
COPY scripts /home/zwzw/scripts

RUN useradd -d /home/zwzw -ms /bin/bash zwzw \
    && echo "zwzw ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/zwzw/printer_data \
    && chown -R zwzw:zwzw /home/zwzw \
    && chmod -R +x /home/zwzw/klipper_install.sh \
    && chmod -R +x /home/zwzw/scripts \
    && sed -i 's#http://deb.debian.org/#http://mirrors.tuna.tsinghua.edu.cn/#' /etc/apt/sources.list.d/debian.sources

ENV TERM=xterm COMPONENTS_ENV=kms

EXPOSE 7125 5001 5002

VOLUME /home/zwzw/printer_data

ENTRYPOINT ["bash","/home/zwzw/klipper_install.sh"]