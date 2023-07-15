FROM ubuntu:22.10
LABEL maintainer="roiding<maodoulove19950815@gmail.com>"

RUN apt update && apt install -y curl gpg supervisor cron\
    && curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | tee /etc/apt/sources.list.d/cloudflare-client.list \
    && apt update && apt install -y cloudflare-warp \
    && apt-get clean

RUN echo "[program:warp-svc]\ncommand=/bin/bash -c /usr/bin/warp-svc\nautostart=true\nautorestart=true\nstartretries=3\nstderr_logfile=/var/log/warp.log\nstdout_logfile=/var/log/warp.log\n" > /etc/supervi
sor/conf.d/warp.conf

RUN echo "supervisord\nsleep 5\n\
    if [ -n \"$KEY\" ]; then \
        warp-cli --accept-tos set-license \"$KEY\"; \
    else \
        warp-cli --accept-tos register; \
    fi\n\
    warp-cli --accept-tos set-proxy-port 40001\n\
    warp-cli --accept-tos set-mode proxy\n\
    warp-cli --accept-tos connect\n\
    tail -f /var/log/warp.log\n" > /init.sh \
    && chmod +x /init.sh

# 添加 cron 定时任务
RUN echo "*/30 * * * * root /bin/bash -c 'warp-cli disconnect && sleep 1 && warp-cli connect'" > /etc/cron.d/warp-cron \
    && chmod 0644 /etc/cron.d/warp-cron \
    && crontab /etc/cron.d/warp-cron
# 安装socat
RUN apt-get update && apt-get install -y socat
RUN echo "[program:socat]" >> /etc/supervisor/conf.d/socat.conf && \
    echo "command=socat TCP-LISTEN:40000,fork,reuseaddr TCP:127.0.0.1:40001" >> /etc/supervisor/conf.d/socat.conf

EXPOSE 40000/tcp

CMD ["bash", "-c", "/init.sh&&cron"]
