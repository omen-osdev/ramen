FROM ubuntu:latest

RUN apt-get update && apt-get install -y build-essential sudo git make fdisk udev gcc nasm parted gdisk dosfstools tree

RUN echo "#!/bin/bash" > /build.sh
RUN echo "cd /omen" >> /build.sh
RUN echo "make clean" >> /build.sh
RUN echo "make cleansetup" >> /build.sh
RUN echo "make setup-gpt" >> /build.sh
RUN echo "make buildimggpt" >> /build.sh
RUN echo "cp ./build/image/limine-cd.img /build/omen.img" >> /build.sh
RUN echo "cp ./build/bin/kernel.elf /build/kernel.elf" >> /build.sh

CMD ["/bin/bash", "/build.sh"]