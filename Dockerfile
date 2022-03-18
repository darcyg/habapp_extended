FROM python:3.10-slim as buildimage

ARG HABAPP_VERSION=Develop

RUN set -eux; \
	#Install download and unpack dependancies
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
		curl \
		unzip \
		libcairo2-dev \
		libgirepository1.0-dev \
		wget; \
	mkdir /tmp/install; \
	cd /tmp/install; \
	#Download and unpack signal-cli
	curl -s https://api.github.com/repos/AsamK/signal-cli/releases/latest \
		| grep "browser_download_url.*Linux.tar.gz" \
		| cut -d : -f 2,3 \
		| tr -d \" \
		| grep ".gz$" \
		| wget -qi -; \
	tar xvf *.tar.gz; \
	rm *.tar.gz; \
	mv signal* signal; \
	#Download and wheel HABApp
	wget https://github.com/spacemanspiff2007/HABApp/archive/refs/heads/${HABAPP_VERSION}.zip; \
	unzip ${HABAPP_VERSION}; \
	rm *.zip; \
	mv HABApp* habapp; \
	cd habapp; \
	pip wheel --wheel-dir=/tmp/install/wheels --use-feature=in-tree-build .; \
	pip wheel --wheel-dir=/tmp/install/wheels pydbus PyGObject;

FROM python:3.10-slim

COPY --from=buildimage /tmp/install /tmp/install

ENV HABAPP_HOME=/habapp \
	SIGNAL_DIR=/opt/signal \
	USER_ID=9001 \
	GROUP_ID=${USER_ID} \
	DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket" \
	SIGNAL_NUMBER= 

RUN set -eux; \
# Install required dependencies
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
		openjdk-17-jre \
		dbus \
		procps \
		libcairo2 \
		libgirepository1.0 \
		gosu \
		tini; \
	ln -s -f $(which gosu) /usr/local/bin/gosu; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*; \
	mkdir -p /run/dbus;

COPY entrypoint.sh /entrypoint.sh
COPY signal/signal.sh /usr/local/bin/signal
COPY signal/org.asamk.Signal.conf /etc/dbus-1/system.d/org.asamk.Signal.conf
COPY signal/org.asamk.Signal.service /usr/share/dbus-1/system-services/org.asamk.Signal.conf

RUN set -eux; \
# install signal-cli
	mkdir -p /opt; \
	cp -r /tmp/install/signal ${SIGNAL_DIR}; \
	chmod +x /usr/local/bin/signal; \
	ln -s ${SIGNAL_DIR}/bin/signal-cli /usr/local/bin; \
	pip3 install \
    	--no-index \
    	--find-links=/tmp/install/wheels \
		pydbus PyGObject; \
# prepare directories
	mkdir -p ${HABAPP_HOME}; \
	mkdir -p ${HABAPP_HOME}/config; \
	mkdir -p ${HABAPP_HOME}/signal; \
# install HABApp
	pip3 install \
    	--no-index \
    	--find-links=/tmp/install/wheels \
		habapp; \
# prepare entrypoint script
	chmod +x /entrypoint.sh; \
# clean up
	rm -rf /tmp/install

WORKDIR ${HABAPP_HOME}
VOLUME ["${HABAPP_HOME}/config" , "${HABAPP_HOME}/signal"]
ENTRYPOINT ["/entrypoint.sh"]

CMD ["tini", "--", "python", "-m", "HABApp", "--config", "./config"]
