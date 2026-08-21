# --- Stage 1: build the fat jar with Maven ---
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B clean package -DskipTests

# --- Stage 2: run on a minimal JRE (not full JDK) ---
FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder /app/target/order-service-*.jar app.jar
USER app
EXPOSE 4004

# -XX:+UseContainerSupport lets the JVM read the pod's cgroup memory/CPU
# limits instead of the host's, so -Xmx sizing actually respects the
# container's `resources.limits.memory` set in the Helm chart.
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]

HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:4004/actuator/health/liveness || exit 1
