# Builder stage
FROM maven:3.8.7-openjdk-18 AS builder
# Enable Java to detect and optimize resource usage in container environments
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport"
COPY . .
RUN mvn clean package -DskipTests
RUN ls -l target
# Final image
FROM flink:1.17.2-scala_2.12-java11
# Copy the built jar from the builder stage
COPY --from=builder /target/fraud-insider-flink-1.0.0.jar /opt/flink/usrlib/fraud-insider-flink-1.0.0.jar
# Enable Java to detect and optimize resource usage in container environments
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport"
