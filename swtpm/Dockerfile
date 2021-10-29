FROM alpine:3.14

SHELL ["/bin/sh", "-x", "-c"]

ARG libtpms=0.9
ARG swtpm=0.6

RUN apk --no-cache add \
	autoconf \
	automake \
	build-base \
	expect \
	gawk \
	git \
	gnutls-dev \
	json-glib-dev \
	libtasn1-dev \
	libseccomp-dev \
	libtool \
	openssl-dev \
	socat

RUN git clone --single-branch --branch stable-$libtpms https://github.com/stefanberger/libtpms.git
RUN git clone --single-branch --branch stable-$swtpm https://github.com/stefanberger/swtpm.git

RUN cd libtpms \
	&& sh autogen.sh \
	&& make -j$(($(getconf _NPROCESSORS_ONLN) + 1)) install

RUN cd swtpm \
	&& sh autogen.sh \
	&& make -j$(($(getconf _NPROCESSORS_ONLN) + 1)) install

ENTRYPOINT ["/usr/local/bin/swtpm"]
CMD ["socket", "--tpmstate", "dir=/run/swtpm,mode=0777", "--ctrl", "type=unixio,path=/run/swtpm/socket,mode=0777", "--tpm2", "--log", "level=5"]
