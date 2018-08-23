.PHONY: all build build_toolchain build_openssl build_pcre build_nginx

SHELL := /bin/bash
DOCKER_IMAGE ?= android-nginx:0.0.1
NGINX_MODULES := $(addprefix --add-module=,$(wildcard ${CURDIR}/nginx-modules/nginx_module_*))

all:
	docker build --network=host -t ${DOCKER_IMAGE} . &&\
	docker run --rm --network=host -it\
		-e CROSS_COMPILE_DEVICE_IP=${CROSS_COMPILE_DEVICE_IP}\
		-e CROSS_COMPILE_DEVICE_PORT=$${CROSS_COMPILE_DEVICE_PORT:-5555}\
		-v ${HOME}/.android:/root/.android\
		-v ${CURDIR}/build:/root/android-nginx/build\
		-v ${CURDIR}/output:/opt/local\
		${DOCKER_IMAGE} build

build: build_toolchain build_openssl build_pcre build_nginx
build_toolchain: ${CURDIR}/build/android-toolchain
build_openssl: /opt/local/lib/libssl.a
build_pcre: /opt/local/lib/libpcre.a
build_nginx: /opt/local/sbin/nginx


# Build toolchain
${CURDIR}/build/android-ndk-r15c-linux-x86_64.zip:
	wget -c https://dl.google.com/android/repository/android-ndk-r15c-linux-x86_64.zip?hl=zh-cn -O ${CURDIR}/build/android-ndk-r15c-linux-x86_64.zip

${CURDIR}/build/android-ndk: ${CURDIR}/build/android-ndk-r15c-linux-x86_64.zip
	unzip ${CURDIR}/build/android-ndk-r15c-linux-x86_64.zip -d ${CURDIR}/build/ &&\
	touch ${CURDIR}/build/android-ndk-r15c &&\
	mv ${CURDIR}/build/android-ndk-r15c ${CURDIR}/build/android-ndk

${CURDIR}/build/android-toolchain: ${CURDIR}/build/android-ndk
	${CURDIR}/build/android-ndk/build/tools/make_standalone_toolchain.py --arch arm64 --api 21 --stl=libc++ --deprecated-headers --install-dir ${CURDIR}/build/android-toolchain


# Build openssl
${CURDIR}/build/openssl-OpenSSL_1_1_0-stable.zip:
	wget https://codeload.github.com/openssl/openssl/zip/OpenSSL_1_1_0-stable -O ${CURDIR}/build/openssl-OpenSSL_1_1_0-stable.zip

${CURDIR}/build/openssl-OpenSSL_1_1_0-stable: ${CURDIR}/build/openssl-OpenSSL_1_1_0-stable.zip
	unzip ${CURDIR}/build/openssl-OpenSSL_1_1_0-stable.zip -d ${CURDIR}/build/ &&\
	touch ${CURDIR}/build/openssl-OpenSSL_1_1_0-stable

${CURDIR}/build/openssl.setenv:
	wget https://raw.githubusercontent.com/couchbaselabs/couchbase-lite-libcrypto/master/build-android-setenv.sh -O ${CURDIR}/build/openssl.setenv &&\
	sed -i -e 's/^_ANDROID_NDK=/#_ANDROID_NDK=/g' ${CURDIR}/build/openssl.setenv

/opt/local/lib/libssl.a: ${CURDIR}/build/openssl-OpenSSL_1_1_0-stable ${CURDIR}/build/openssl.setenv
	export ANDROID_NDK_ROOT=${CURDIR}/build/android-ndk;\
	export _ANDROID_TARGET_SELECT=arch-arm64-v8a;\
	export _ANDROID_NDK="android-ndk";\
	export ANDROID_EABI_PREFIX=aarch64-linux-android;\
	export _ANDROID_EABI=$${ANDROID_EABI_PREFIX}-4.9;\
	export _ANDROID_ARCH=arch-arm64;\
	export _ANDROID_API="android-21";\
	source ${CURDIR}/build/openssl.setenv;\
	echo "env: " &&\
	env &&\
	echo "" &&\
	cd ${CURDIR}/build/openssl-OpenSSL_1_1_0-stable &&\
    ./Configure dist &&\
    ./Configure no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared --openssldir=/opt/local/ --prefix=/opt/local/ linux-generic64 -DB_ENDIAN -B$${ANDROID_DEV}/lib \
		        -I$${ANDROID_DEV}/include -L$${ANDROID_DEV}/lib \
		        -fPIE -pie &&\
    make -j6 &&\
    make install


# Build libpcre
${CURDIR}/build/pcre-8.42.tar.gz:
	wget https://superb-sea2.dl.sourceforge.net/project/pcre/pcre/8.42/pcre-8.42.tar.gz -O ${CURDIR}/build/pcre-8.42.tar.gz

${CURDIR}/build/pcre-8.42: ${CURDIR}/build/pcre-8.42.tar.gz
	tar xzvf ${CURDIR}/build/pcre-8.42.tar.gz -C ${CURDIR}/build/ &&\
	touch ${CURDIR}/build/pcre-8.42

/opt/local/lib/libpcre.a: ${CURDIR}/build/pcre-8.42
	source ${CURDIR}/ndk.env &&\
	echo "env: " &&\
	env &&\
	echo "" &&\
	cd ${CURDIR}/build/pcre-8.42 &&\
	./configure --prefix=/opt/local --host=$${CROSS_COMPILE_HOST} --disable-shared &&\
	make &&\
	make install


# Build nginx
${CURDIR}/build/nginx-1.14.0.tar.gz:
	wget https://nginx.org/download/nginx-1.14.0.tar.gz -O ${CURDIR}/build/nginx-1.14.0.tar.gz

${CURDIR}/build/nginx-1.14.0: ${CURDIR}/build/nginx-1.14.0.tar.gz
	rm -rf "${CURDIR}/build/nginx-1.14.0" &&\
	tar xzvf ${CURDIR}/build/nginx-1.14.0.tar.gz -C ${CURDIR}/build/ &&\
	cd ${CURDIR}/build/nginx-1.14.0 &&\
	sed -i -e 's/\/bin\/sh -c $$NGX_AUTOTEST/timeout 10 remote.run -f $$NGX_AUTOTEST/g' `find auto -type f` &&\
	sed -i -e 's/$$NGX_AUTOTEST >\/dev\/null/timeout 10 remote.run -f $$NGX_AUTOTEST >\/dev\/null/g' `find auto -type f` &&\
	sed -i -e 's/`$$NGX_AUTOTEST`/`timeout 10 remote.run -f $$NGX_AUTOTEST`/g' `find auto -type f` &&\
	sed -i -e 's/#include <crypt.h>/#if (NGX_HAVE_CRYPT_H)\n#include <crypt.h>\n#endif\n#include <openssl\/des.h>/g' src/os/unix/ngx_linux_config.h &&\
	sed -i -e 's/= crypt(/= DES_crypt(/g' src/os/unix/ngx_user.c &&\
	wget https://github.com/tatowilson/Cross-Compile-Nginx-with-RTMP-Module-for-Android/raw/master/glob/glob.h -O src/os/unix/glob.h &&\
	wget https://github.com/tatowilson/Cross-Compile-Nginx-with-RTMP-Module-for-Android/raw/master/glob/glob.c -O src/os/unix/glob.c &&\
	sed -i -e 's/^UNIX_DEPS="/UNIX_DEPS="src\/os\/unix\/glob.h \\\n            /g' auto/sources &&\
	sed -i -e 's/^UNIX_SRCS="/UNIX_SRCS="src\/os\/unix\/glob.c \\\n            /g' auto/sources

/opt/local/sbin/nginx: ${CURDIR}/build/nginx-1.14.0
	export PATH=$(PATH):${CURDIR} &&\
	source ${CURDIR}/ndk.env &&\
	echo "env: " &&\
	env &&\
	echo "" &&\
	cd ${CURDIR}/build/nginx-1.14.0 &&\
	CC_TEST_FLAGS="$${CFLAGS} $${LDFLAGS}" ./configure --prefix=/opt/local --with-ld-opt="$${LDFLAGS}" --with-cc-opt="-DIOV_MAX=1024 -D_FILE_OFFSET_BITS=64" --crossbuild=`timeout 10 remote.run -c 'uname -srm' | tr ' ' ':'` --user=root --group=root --with-select_module --with-poll_module --with-file-aio --with-http_ssl_module --without-mail_pop3_module --without-mail_imap_module  --without-mail_smtp_module ${NGINX_MODULES} &&\
	make &&\
	make install
