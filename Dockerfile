FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ansible \
    iputils-ping \
    net-tools \
    curl \
    apache2 \
    vim && \
    mkdir -p /app/templates /app/static

WORKDIR /app

COPY app/ /app/

RUN pip3 install -r requirements.txt
RUN chmod +x /app/start.sh

EXPOSE 5000

CMD ["bash", "/app/start.sh"]
