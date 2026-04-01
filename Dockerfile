FROM eclipse-temurin:25-jre-ubi10-minimal AS builder

SHELL ["/bin/bash", "-c"]

# Get this URL via https://fabricmc.net/use/server/
ARG SERVER_JAR_URL=https://meta.fabricmc.net/v2/versions/loader/26.1/0.18.6/1.1.1/server/jar
ARG MINECRAFT_DIR=/opt/minecraft-server

RUN microdnf install -y curl && microdnf clean all

RUN mkdir -p ${MINECRAFT_DIR}/mods

WORKDIR ${MINECRAFT_DIR}

RUN curl -fSL "${SERVER_JAR_URL}" -o server.jar

COPY mods.txt /tmp/mods.txt
RUN while read -r url filename; do \
      [[ -z "$url" || "$url" == '#'* || -z "$filename" ]] && continue; \
      echo "Downloading mod: ${filename}"; \
      curl -fSL "$url" -o "mods/${filename}"; \
    done < /tmp/mods.txt

RUN printf "eula=true\n" > eula.txt

COPY server.properties.default server.properties.default


FROM eclipse-temurin:25-jre-ubi10-minimal

ARG MINECRAFT_DIR=/opt/minecraft-server

RUN microdnf install -y jq && microdnf clean all && \
    groupadd -r minecraft && \
    useradd -r -g minecraft -d ${MINECRAFT_DIR} -s /sbin/nologin -u 1000 minecraft && \
    mkdir -p ${MINECRAFT_DIR}/world /data/config && \
    chown minecraft:minecraft ${MINECRAFT_DIR} /data/config

COPY --from=builder --chown=minecraft:minecraft ${MINECRAFT_DIR} ${MINECRAFT_DIR}
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

VOLUME ${MINECRAFT_DIR}/world
EXPOSE 25565

USER minecraft
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
