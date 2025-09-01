# Builder stage
FROM maven:3.8.7-openjdk-11 AS builder
# Enable Java to detect and optimize resource usage in container environments
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport"
COPY . .
RUN mvn clean package -DskipTests

# Final image
FROM flink:1.17.2-scala_2.12-java11
COPY --from=builder /app/target/fraud-insider-flink-1.0.0.jar /opt/flink/usrlib/fraud-insider-flink-1.0.0.jar
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport"
