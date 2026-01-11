# =============================================================================
# OpenTripPlanner v2.5 - Multi-stage Dockerfile
# MaaS Platform - Phase 2: Routing Engine
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Downloader - Pobierz OTP JAR
# -----------------------------------------------------------------------------
FROM eclipse-temurin:21-jdk-alpine AS downloader

ENV OTP_VERSION=2.5.0

WORKDIR /download

# Zainstaluj wget
RUN apk add --no-cache wget

# Pobierz OTP shaded JAR
RUN wget -q "https://repo1.maven.org/maven2/org/opentripplanner/otp/${OTP_VERSION}/otp-${OTP_VERSION}-shaded.jar" \
    -O otp.jar && \
    echo "Downloaded OTP ${OTP_VERSION}"

# -----------------------------------------------------------------------------
# Stage 2: Graph Builder - Zbuduj graf (osobny stage dla cache)
# -----------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine AS builder

WORKDIR /opt/otp

# Zainstaluj bash i inne narzędzia do debugowania
RUN apk add --no-cache bash

# Kopiuj OTP
COPY --from=downloader /download/otp.jar /opt/otp/otp.jar

# Katalog na dane - będzie zamontowany jako volume
RUN mkdir -p /opt/otp/data

# Graf będzie budowany przez docker-compose z odpowiednim command
# java -Xmx8G -jar otp.jar --build --save /opt/otp/data

# -----------------------------------------------------------------------------
# Stage 3: Runtime - Uruchom serwer OTP
# -----------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine AS runtime

LABEL maintainer="MaaS Platform Team"
LABEL description="OpenTripPlanner v2.5 for MaaS Multimodal Routing"
LABEL version="2.5.0"

WORKDIR /opt/otp

# Utwórz użytkownika non-root
RUN addgroup -g 1000 otp && \
    adduser -u 1000 -G otp -h /opt/otp -D otp

# Kopiuj OTP JAR
COPY --from=downloader /download/otp.jar /opt/otp/otp.jar

# Kopiuj konfiguracje
COPY build-config.json /opt/otp/
COPY router-config.json /opt/otp/

# Utwórz katalog na dane
RUN mkdir -p /opt/otp/data && \
    chown -R otp:otp /opt/otp

# Przełącz na użytkownika otp
USER otp

# Expose ports
# 8080 - API (REST + GraphQL)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=3 \
    CMD wget -q --spider http://localhost:8080/otp/actuators/health || exit 1

# Default environment variables
ENV JAVA_OPTS="-Xmx4G -Xms1G"
ENV OTP_DATA_DIR="/opt/otp/data"

# Entry point - uruchom w trybie serve
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar /opt/otp/otp.jar --load ${OTP_DATA_DIR} --serve"]
