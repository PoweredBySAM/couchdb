FROM ubuntu:trusty

ENV COUCHDB_VERSION couchdb-search

ENV MAVEN_VERSION 3.3.3

ENV DEBIAN_FRONTEND noninteractive



RUN groupadd -r couchdb && useradd -d /usr/src/couchdb -g couchdb couchdb

# download dependencies
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential libmozjs185-dev \
    libnspr4 libnspr4-0d libnspr4-dev libcurl4-openssl-dev libicu-dev \
    openssl curl ca-certificates git pkg-config \
    apt-transport-https python wget \
    python-sphinx texlive-base texinfo texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra #needed to build the doc

RUN wget http://packages.erlang-solutions.com/erlang/esl-erlang/FLAVOUR_1_general/esl-erlang_18.1-1~ubuntu~precise_amd64.deb
RUN apt-get install -y --no-install-recommends openjdk-7-jdk
RUN apt-get install -y --no-install-recommends procps
RUN apt-get install -y --no-install-recommends libwxgtk2.8-0

RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
  && curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/1.7/gosu-$(dpkg --print-architecture)" \
  && curl -o /usr/local/bin/gosu.asc -fSL "https://github.com/tianon/gosu/releases/download/1.7/gosu-$(dpkg --print-architecture).asc" \
  && gpg --verify /usr/local/bin/gosu.asc \
  && rm /usr/local/bin/gosu.asc \
  && chmod +x /usr/local/bin/gosu \
  && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 6380DC428747F6C393FEACA59A84159D7001A4E5 \
  && curl -o /usr/local/bin/tini -fSL "https://github.com/krallin/tini/releases/download/v0.9.0/tini" \
  && curl -o /usr/local/bin/tini.asc -fSL "https://github.com/krallin/tini/releases/download/v0.9.0/tini.asc" \
  && gpg --verify /usr/local/bin/tini.asc \
  && rm /usr/local/bin/tini.asc \
  && chmod +x /usr/local/bin/tini

RUN dpkg -i esl-erlang_18.1-1~ubuntu~precise_amd64.deb

RUN curl -fsSL http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar xzf - -C /usr/share \
  && mv /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven

RUN curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - \
  && apt-get install -y nodejs \
  && npm install -g npm && npm install -g grunt-cli

RUN cd /usr/src \
 && git clone https://github.com/PoweredBySAM/couchdb.git \
 && cd couchdb \
 && git checkout v2-full-text-search \
 && ./configure --disable-docs \
 && make release \
 && mv /usr/src/couchdb/rel/couchdb /opt/ 

RUN cd /usr/src \
 && git clone https://github.com/cloudant-labs/clouseau \
 && cd /usr/src/clouseau \
 && mvn -Dmaven.test.skip=true install

RUN apt-get -y install haproxy

RUN apt-get install -y supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir -p /var/log/supervisor/ \
 && chmod 755 /var/log/supervisor/

# Expose to the outside
RUN sed -i'' 's/bind_address = 127.0.0.1/bind_address = 0.0.0.0/' /usr/src/couchdb/rel/overlay/etc/default.ini

# Add configuration
COPY local.ini /opt/couchdb/etc/
COPY vm.args /opt/couchdb/etc/

COPY ./docker-entrypoint.sh /

# Setup directories and permissions
RUN chmod +x /docker-entrypoint.sh \
 && mkdir /opt/couchdb/data /opt/couchdb/etc/local.d /opt/couchdb/etc/default.d \
 && chown -R couchdb:couchdb /opt/couchdb/

WORKDIR /opt/couchdb
EXPOSE 5984 4369 9100
VOLUME ["/opt/couchdb/data"]

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
ENTRYPOINT ["/usr/bin/supervisord"]
