# https://github.com/pa11y/pa11y-ci#docker
FROM node:16-buster-slim

# HTTP Proxy
ARG http_proxy
ARG https_proxy
ARG npm_version=8.12.1

ENV http_proxy=${http_proxy}
ENV HTTP_PROXY=${http_proxy}
ENV https_proxy=${https_proxy}
ENV HTTPS_PROXY=${https_proxy}

RUN mkdir pa11ywrk
WORKDIR /app
COPY package.json package-lock.json config.json reporter.js ./

# Certificate logic. This is only required for local developer builds (not CI builds), hence conditional logic
# if --build-arg http_proxy has a value, set CERT_HOME to /etc/ssl/certs (see https://docs.docker.com/engine/reference/builder/#environment-replacement)
ENV CERT_HOME=${http_proxy:+/etc/ssl/certs}
ENV CERT_FILE_PATH=${http_proxy:+${CERT_HOME}/ca-certificates.crt}

# Setup npm proxy if arg http_proxy is not empty
RUN if [ -n "$http_proxy" ] ; then \
    npm config set cafile ${CERT_FILE_PATH} ; \
    npm config set proxy ${http_proxy} ; \
    npm config set https-proxy ${https_proxy} ; \
    npm config set strict-ssl false ; \
    fi;
	
RUN --mount=type=secret,id=cert,dst=/etc/ssl/certs/ca-certificates.crt apt-get update && apt-get install -y wget gnupg ca-certificates procps libxss1 \
        && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
        && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
        && apt-get update \
        && apt-get install -y google-chrome-stable \
        && rm -rf /var/lib/apt/lists/* \
        && wget --quiet https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -O /usr/sbin/wait-for-it.sh \
        && chmod +x /usr/sbin/wait-for-it.sh

# We use pipe in the next RUN, so mitigate this warning (https://github.com/hadolint/hadolint/wiki/DL4006)

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Diagnostic logging (to allow confirmation that npm config and .npmrc are correct inside container)
RUN --mount=type=secret,id=npm,dst=/app/.npmrc echo "=======" && ls -al && echo "-------" && npm config list && echo "-------" && cat .npmrc && echo "-------" && printenv | sort && echo "======"

RUN npm cache clean --force && rm -rf node_modules

# Restore packages, using mounted .npmrc file
RUN --mount=type=secret,id=npm,dst=/app/.npmrc --mount=type=secret,id=cert,dst=/etc/ssl/certs/ca-certificates.crt npm install -g npm@${npm_version} && \
    npm --verbose --no-audit ci

RUN --mount=type=secret,id=npm,dst=/app/.npmrc --mount=type=secret,id=cert,dst=/etc/ssl/certs/ca-certificates.crt npm install
# # RUN npm install -g --unsafe-perm pa11y-ci-reporter-html
RUN --mount=type=secret,id=npm,dst=/app/.npmrc --mount=type=secret,id=cert,dst=/etc/ssl/certs/ca-certificates.crt npm install -D --unsafe-perm pa11y-ci@3.0.1

# ENTRYPOINT ["pa11y-ci", "-c", "/app/config.json"]
CMD ["npm", "run", "test-pa11y"]
