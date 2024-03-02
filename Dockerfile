ARG product_version=8.0.1
ARG build_tag=v8.0.1.1
ARG build_number=1
ARG oo_root='/var/www/onlyoffice/documentserver'

## Setup
FROM onlyoffice/documentserver:${product_version}.${build_number} as setup-stage
ARG product_version
ARG build_number
ARG oo_root

ENV PRODUCT_VERSION=${product_version}
ENV BUILD_NUMBER=${build_number}

ARG build_deps="git make g++ bzip2"
RUN apt-get update && apt-get install -y ${build_deps} && \
    sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    NODE_MAJOR=18 && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list && \
    sudo apt-get update && sudo apt-get install nodejs -y && \
    npm install -g pkg grunt grunt-cli && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build


## Clone
FROM setup-stage as clone-stage
ARG build_tag

RUN git clone --quiet --branch $build_tag --depth 1 https://github.com/ONLYOFFICE/build_tools.git /build/build_tools
RUN git clone --quiet --branch $build_tag --depth 1 https://github.com/ONLYOFFICE/server.git      /build/server

# Working mobile editor
RUN git clone --quiet --depth 1 https://github.com/ONLYOFFICE/sdkjs.git       /build/sdkjs
RUN git clone --quiet --depth 1 https://github.com/ONLYOFFICE/web-apps.git    /build/web-apps

## Build
FROM clone-stage as path-stage

# patch
COPY web-apps.patch /build/web-apps.patch
RUN cd /build/web-apps   && git apply /build/web-apps.patch

COPY server.patch /build/server.patch
RUN cd /build/server && git apply --ignore-space-change --ignore-whitespace /build/server.patch


## Build
FROM path-stage as build-stage

# build server with license checks patched
WORKDIR /build/server
RUN make
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/FileConverter --targets=node18-linux -o /build/converter
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/DocService --targets=node18-linux --options max_old_space_size=4096 -o /build/docservice

## Final image
FROM onlyoffice/documentserver:${product_version}.${build_number}
ARG oo_root

#server
COPY --from=build-stage /build/converter  ${oo_root}/server/FileConverter/converter
COPY --from=build-stage /build/docservice ${oo_root}/server/DocService/docservice

# Restore mobile editing using an old version of mobile editor
#COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/documenteditor/mobile     ${oo_root}/web-apps/apps/documenteditor/mobile
#COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/presentationeditor/mobile ${oo_root}/web-apps/apps/presentationeditor/mobile
#COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/spreadsheeteditor/mobile  ${oo_root}/web-apps/apps/spreadsheeteditor/mobile
