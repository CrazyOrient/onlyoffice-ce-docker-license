ARG product_version=8.0.0
ARG build_tag=v8.0.1.30
ARG build_number=1
ARG oo_root='/var/www/onlyoffice/documentserver'

## Setup
FROM onlyoffice/documentserver:${product_version}.${build_number} as setup-stage
ARG product_version
ARG build_number
ARG oo_root

ENV PRODUCT_VERSION=${product_version}
ENV BUILD_NUMBER=${build_number}


ARG build_deps="git make g++ nodejs npm"
RUN apt-get update && apt-get install -y ${build_deps}
RUN npm install -g pkg grunt grunt-cli && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build


## Clone
FROM setup-stage as clone-stage
ARG build_tag

RUN git clone --quiet --branch $build_tag --depth 1 https://github.com/ONLYOFFICE/build_tools.git /build/build_tools
RUN git clone --quiet --branch $build_tag --depth 1 https://github.com/ONLYOFFICE/server.git      /build/server

## Build
FROM clone-stage as path-stage

COPY server.patch /build/server.patch
RUN cd /build/server && git apply --ignore-space-change --ignore-whitespace /build/server.patch


## Build
FROM path-stage as build-stage

# build server with license checks patched
WORKDIR /build/server
RUN make
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/FileConverter --targets=node14-linux -o /build/converter
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/DocService --targets=node14-linux --options max_old_space_size=4096 -o /build/docservice

## Final image
FROM onlyoffice/documentserver:${product_version}.${build_number}
ARG oo_root

#server
COPY --from=build-stage /build/converter  ${oo_root}/server/FileConverter/converter
COPY --from=build-stage /build/docservice ${oo_root}/server/DocService/docservice

