FROM debian:buster-slim

ENV RUBY_MAJOR 2.7
ENV RUBY_VERSION 2.7.1
ENV RUBY_DOWNLOAD_SHA256 b224f9844646cc92765df8288a46838511c1cec5b550d8874bd4686a904fcee7
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $GEM_HOME/bin:$PATH

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		autoconf \
		bison \
		bzip2 \
		ca-certificates \
		dpkg-dev \
		gcc \
		libbz2-dev \
		libffi-dev \
		libgdbm-compat-dev \
		libgdbm-dev \
		libglib2.0-dev \
		libgmp-dev \
		libjemalloc-dev \
		libncurses-dev \
		libreadline-dev \
		libssl-dev \
		libxml2-dev \
		libxslt-dev \
		libyaml-dev \
		make \
		procps \
		ruby \
		wget \
		xz-utils \
		zlib1g-dev \
    build-essential \
    curl \
    git-core \
    libpq-dev \
    locales \
    nodejs \
    tzdata \
    unzip \
	; \
	rm -rf /var/lib/apt/lists/* \
  ; \
	mkdir -p /usr/local/etc; \
	{ \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc \
  ; \
	\
	wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"; \
	echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict; \
	\
	mkdir -p /usr/src/ruby; \
	tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1; \
	rm ruby.tar.xz; \
	\
	cd /usr/src/ruby; \
	\
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
	{ \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new; \
	mv file.c.new file.c; \
	\
	autoconf; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--with-jemalloc \
		--disable-install-doc \
		--enable-shared \
	; \
	make -j "$(nproc)"; \
	make install; \
	\
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	cd /; \
	rm -r /usr/src/ruby; \
# verify we have no "ruby" packages installed
	! dpkg -l | grep -i ruby; \
	[ "$(command -v ruby)" = '/usr/local/bin/ruby' ]; \
# rough smoke test
	ruby --version; \
	gem --version; \
	bundle --version; \
  \
# adjust permissions of a few directories for running "gem install" as an arbitrary user
  mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME"

# Sanity check for jemalloc
# RUN ruby -r rbconfig -e "abort 'jemalloc not enabled' unless RbConfig::CONFIG['LIBS'].include?('jemalloc') || RbConfig::CONFIG['MAINLIBS'].include?('jemalloc')"

CMD [ "irb" ]
