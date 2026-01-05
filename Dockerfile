FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y elogind

RUN echo "=== DPKG LIST ===" && \
    dpkg -L elogind | grep -E "(bin|sbin|libexec)" && \
    echo "=== FIND ===" && \
    find / -name "*elogind*" -executable -type f 2>/dev/null


CMD ["bash", "-c", "cat /dev/null"]
