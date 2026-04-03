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
COPY server.properties.default server.properties


FROM eclipse-temurin:25-jre-ubi10-minimal

ARG MINECRAFT_DIR=/opt/minecraft-server

RUN microdnf install -y jq && microdnf clean all && \
    groupadd -r minecraft && \
    useradd -r -g minecraft -d ${MINECRAFT_DIR} -s /sbin/nologin -u 1000 minecraft && \
    for DIR in world versions libraries logs config .fabric; do \
      mkdir -p ${MINECRAFT_DIR}/$DIR && \
      chown minecraft:minecraft ${MINECRAFT_DIR}/$DIR; \
    done && \
    mkdir -p /data/config && chown minecraft:minecraft /data/config && \
    for FILE in banned-ips.json banned-players.json ops.json whitelist.json; do \
      echo -n "[]" > /data/config/$FILE && \
      chown minecraft:minecraft /data/config/$FILE && \
      ln -s /data/config/$FILE ${MINECRAFT_DIR}/$FILE; \
    done
    

COPY --from=builder --chown=minecraft:minecraft ${MINECRAFT_DIR} ${MINECRAFT_DIR}
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENV HOME=${MINECRAFT_DIR}
WORKDIR ${MINECRAFT_DIR}

VOLUME ${MINECRAFT_DIR}/world
VOLUME /data/config
EXPOSE 25565

USER minecraft
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
