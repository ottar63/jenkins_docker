#FROM openjdk:8-jdk-stretch
FROM openjdk:11

#Originale
#RUN apt-get update \
#       && apt-get upgrade -y \
#       && apt-get install -y git curl \
#       apt-transport-https \
#       ca-certificates \
#       gnupg2 \
#       software-properties-common \
#       && rm -rf /var/lib/apt/lists/*
#Removed apt-get upgrade
RUN apt-get update \
       && apt-get install --no-install-recommends -y git curl \
       apt-transport-https \
       ca-certificates \
       gnupg2 \
       software-properties-common \
       && rm -rf /var/lib/apt/lists/*


ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG docker_gid=997
ARG http_port=8080
ARG agent_port=50000
ARG REF=/usr/share/jenkins/ref

ENV REF $REF
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid

RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p ${REF}/init.groovy.d

ARG TINI_VERSION=v0.19.0
ENV TINI_SHA 93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c|

COPY tini_pub.gpg ${JENKINS_HOME}/tini_pub.gpg

# Use tini as subreaper in Docker container to adopt zombie processes 

RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static -o /sbin/tini \
	&& curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static.asc -o /sbin/tini.asc \
	&& gpg --no-tty --import ${JENKINS_HOME}/tini_pub.gpg \
	&& gpg --verify /sbin/tini.asc \
	&& chmod +x /sbin/tini  


# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.452.2}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=360efc8438db9a4ba20772981d4257cfe6837bf0c3fb8c8e9b2253d8ce6ba339

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# Add Docker
RUN groupadd -g ${docker_gid} docker 
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository \
   "deb https://download.docker.com/linux/debian buster\
   stable"
RUN apt-get update  -qq \
    && apt-get install --no-install-recommends docker-ce -y
RUN usermod -aG docker jenkins

#  Having issue with pushing overlay2 images , get device or resource busy
#  workaround is to configure docker to only push 1 overlay at a time
#  ref : https://github.com/docker/for-linux/issues/711
COPY daemon.json /etc/docker/daemon.json

# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# problem with setting local timezone and caching in docker 
ARG CACHEBUST=1 
# set correct TimeZone
RUN rm -rf /etc/localtime && ln -s /usr/share/zoneinfo/Europe/Oslo /etc/localtime

USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
