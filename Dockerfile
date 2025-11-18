FROM golang:bookworm AS go-builder

RUN GO111MODULE=on go install github.com/jaeles-project/gospider@latest 
RUN go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
RUN go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
RUN go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest


FROM ubuntu:24.04 AS base
 
RUN apt-get update && apt-get install -y \
  python3 \
  python3-pip \
  ffmpeg \
  libsm6 \
  libxext6 \
  libpcap-dev \
  xsltproc \
  nmap \
  curl \
  htop \
  nano \
  iputils-ping \
  wget \
  git \
  chromium-browser \
  unzip \
  parallel \
  ca-certificates \
  gnupg \
  lsb-release \
&& rm -rf /var/lib/apt/lists/*


RUN mkdir -m 0755 -p /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y && rm -rf /var/lib/apt/lists/*


RUN pip install difPy dirsearch --break-system-packages


# COPY --from=golang:bookworm /usr/local/go/ /usr/local/go/
# ENV PATH="/usr/local/go/bin:${PATH}"


RUN mkdir /tools
WORKDIR /tools


RUN git clone https://github.com/ernw/nmap-parse-output


RUN git clone https://github.com/projectdiscovery/nuclei-templates.git /root/nuclei-templates


RUN git clone https://github.com/robertdavidgraham/masscan
WORKDIR /tools/masscan
RUN make && make install
WORKDIR /tools
RUN rm -rf /tools/masscan


RUN wget https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip
RUN unzip aquatone_linux_amd64_1.7.0.zip -d /tools/aquatone
RUN rm -f aquatone_linux_amd64_1.7.0.zip

# fix the parallel output
RUN parallel --will-cite

COPY acunetix.py /tools/KageRecon/
COPY cidr.sh /tools/KageRecon/
COPY dKageRecon.sh /tools/KageRecon/
COPY express_file.py /tools/KageRecon/
COPY express_pic.py /tools/KageRecon/
COPY express_text.py /tools/KageRecon/
COPY pic_dedup.py /tools/KageRecon/
COPY scan_with_acunetix.sh /tools/KageRecon/
COPY scan_with_brutespray.sh /tools/KageRecon/

RUN chmod +x /tools/KageRecon/cidr.sh 
RUN chmod +x /tools/KageRecon/KageRecon.sh 
RUN chmod +x /tools/KageRecon/scan_with_acunetix.sh 
RUN chmod +x /tools/KageRecon/scan_with_brutespray.sh 

#RUN wget https://gitlab.com/api/v4/projects/33695681/packages/generic/nrich/0.3.1/nrich_0.3.1_amd64.deb
#RUN dpkg -i nrich_0.3.1_amd64.deb
#RUN rm -f nrich_0.3.1_amd64.deb

WORKDIR /tools/KageRecon
RUN mkdir /tools/KageRecon/logs

RUN mkdir /root/go
RUN mkdir /root/go/bin/

SHELL [ "/bin/bash", "-c" ]
ENTRYPOINT [ "./KageRecon.sh" ]

FROM base AS final
COPY --from=go-builder /go/bin/gospider /go/bin/subfinder /go/bin/httpx /go/bin/nuclei /root/go/bin/