FROM eclipse-temurin:25-jre-ubi10-minimal

ARG MINECRAFT_DIR=/opt/minecraft-server
ARG SERVER_JAR_URL=https://meta.fabricmc.net/v2/versions/loader/1.21.11/0.18.5/1.1.1/server/jar

RUN microdnf install -y curl jq findutils && microdnf clean all

RUN groupadd -r minecraft && \
    useradd -r -g minecraft -d ${MINECRAFT_DIR} -s /bin/bash -u 1000 minecraft

RUN mkdir -p ${MINECRAFT_DIR}/mods ${MINECRAFT_DIR}/world /data/config && \
    chown -R minecraft:minecraft ${MINECRAFT_DIR} /data/config

WORKDIR ${MINECRAFT_DIR}

# Download Fabric server jar
RUN curl -fSL "${SERVER_JAR_URL}" -o server.jar

# Download mods from mods.txt (space-separated: URL filename)
COPY mods.txt /tmp/mods.txt
RUN while read -r url filename; do \
      case "$url" in \
        \#*|"") continue ;; \
      esac; \
      [ -z "$filename" ] && continue; \
      echo "Downloading mod: ${filename}"; \
      curl -fSL "$url" -o "mods/${filename}"; \
    done < /tmp/mods.txt && rm /tmp/mods.txt

# Approve EULA
RUN printf "eula=true\n" > eula.txt

# Copy default server properties and entrypoint
COPY server.properties.default server.properties.default
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN chown -R minecraft:minecraft ${MINECRAFT_DIR}

VOLUME ${MINECRAFT_DIR}/world
EXPOSE 25565

USER minecraft
ENTRYPOINT ["/entrypoint.sh"]
