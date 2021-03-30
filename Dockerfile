FROM centos/s2i-base-centos8

# This image provides a Ruby environment you can use to run your Ruby
# applications.

EXPOSE 8080
EXPOSE 8081

ENV RUBY_MAJOR_VERSION=2 \
    RUBY_MINOR_VERSION=7

# Ruby env stuff
ENV RUBY_VERSION="${RUBY_MAJOR_VERSION}.${RUBY_MINOR_VERSION}" \
    RUBY_SCL_NAME_VERSION="${RUBY_MAJOR_VERSION}${RUBY_MINOR_VERSION}"

# Nginx env stuff
ENV NGINX_CONFIGURATION_PATH=${APP_ROOT}/etc/nginx.d \
    NGINX_CONF_PATH=/etc/opt/rh/rh-nginx${NGINX_SHORT_VER}/nginx/nginx.conf \
    NGINX_DEFAULT_CONF_PATH=${APP_ROOT}/etc/nginx.default.d \
    NGINX_CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/nginx \
    NGINX_APP_ROOT=${APP_ROOT} \
    NGINX_LOG_PATH=/var/opt/rh/rh-nginx${NGINX_SHORT_VER}/log/nginx \
    NGINX_PERL_MODULE_PATH=${APP_ROOT}/etc/perl

ENV RUBY_SCL="ruby-${RUBY_SCL_NAME_VERSION}" \
    IMAGE_NAME="centos8/ruby-${RUBY_SCL_NAME_VERSION}" \
    SUMMARY="Platform for building and running Ruby $RUBY_VERSION applications" \
    DESCRIPTION="Ruby $RUBY_VERSION available as container is a base platform for \
building and running various Ruby $RUBY_VERSION applications and frameworks. \
Ruby is the interpreted scripting language for quick and easy object-oriented programming. \
It has many features to process text files and to do system management tasks (as in Perl). \
It is simple, straight-forward, and extensible."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Ruby ${RUBY_VERSION}" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,ruby,ruby${RUBY_SCL_NAME_VERSION},${RUBY_SCL}" \
      com.redhat.component="${RUBY_SCL}-container" \
      name="${IMAGE_NAME}" \
      version="1" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI" \
      usage="s2i build https://github.com/sclorg/s2i-ruby-container.git \
--context-dir=${RUBY_VERSION}/test/puma-test-app/ ${IMAGE_NAME} ruby-sample-app" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>"

RUN yum -y install epel-release

RUN yum -y module enable ruby:$RUBY_VERSION && \
    INSTALL_PKGS=" \
    libffi-devel \
    ruby \
    ruby-devel \
    rubygem-rake \
    rubygem-bundler \
    redhat-rpm-config \
    " && \
    yum install -y --setopt=tsflags=nodocs ${INSTALL_PKGS} && \
    yum -y clean all --enablerepo='*' && \
    rpm -V ${INSTALL_PKGS}

RUN yum install -y nginx ImageMagick brotli; yum clean all

RUN npm install -g uglify-js && npm install -g svgo
RUN mkdir -p /var/nginx/cache
RUN /usr/bin/chmod -R 770 /var/{lib,log}/nginx/ && chown -R :root /var/{lib,log}/nginx/

# Copy Nginx discourse config files
COPY ./nginx.global.conf /etc/nginx/nginx.conf
COPY ./nginx.conf /etc/nginx/conf.d/discourse.conf

# Copy Puma socket file
COPY ./puma.sock /tmp/sockets/puma.sock

# This should allow nginx-sidecar to start without priviledge escilation
RUN touch /run/nginx.pid \
 && chmod -R 666 /run/nginx.pid

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Copy extra files to the image.
COPY ./root/ /

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:0 ${APP_ROOT} && chmod -R ug+rwx ${APP_ROOT} #&& \
    #rpm-file-permissions

RUN sed -i -f ${NGINX_APP_ROOT}/nginxconf.sed ${NGINX_CONF_PATH} && \
    chmod a+rwx ${NGINX_CONF_PATH} && \
    mkdir -p ${NGINX_APP_ROOT}/etc/nginx.d/ && \
    mkdir -p ${NGINX_APP_ROOT}/etc/nginx.default.d/ && \
    mkdir -p ${NGINX_APP_ROOT}/src/nginx-start/ && \
    mkdir -p ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start && \
    mkdir -p ${NGINX_LOG_PATH} && \
    mkdir -p ${NGINX_PERL_MODULE_PATH} && \
    ln -s ${NGINX_LOG_PATH} /var/log/nginx && \
    ln -s /etc/opt/rh/rh-nginx${NGINX_SHORT_VER}/nginx /etc/nginx && \
    ln -s /opt/rh/rh-nginx${NGINX_SHORT_VER}/root/usr/share/nginx /usr/share/nginx && \
    chmod -R a+rwx ${NGINX_APP_ROOT}/etc && \
    chmod -R a+rwx /var/opt/rh/rh-nginx${NGINX_SHORT_VER} && \
    chmod -R a+rwx ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start && \
    chown -R 1001:0 ${NGINX_APP_ROOT} && \
    chown -R 1001:0 /var/opt/rh/rh-nginx${NGINX_SHORT_VER} && \
    chown -R 1001:0 ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start && \
    chmod -R a+rwx /var/run && \
    chown -R 1001:0 /var/run && \
    rpm-file-permissions

RUN touch /run/nginx.pid \
 && chmod -R 777 /run/nginx.pid
RUN chown -R 1001:1001 /run/nginx.pid

USER 1001


ENV BASH_ENV=${NGINX_APP_ROOT}/etc/scl_enable \
    ENV=${NGINX_APP_ROOT}/etc/scl_enable \
    PROMPT_COMMAND=". ${NGINX_APP_ROOT}/etc/scl_enable"

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage
