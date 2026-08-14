# Built inside Docker on purpose: the machine has a JDK but no Maven, and the
# server should not need one installed to build. Two stages so the runtime image
# carries a JRE and a jar rather than a full toolchain.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
# Dependencies first, as their own layer, so editing Kotlin does not re-download
# Spring on every build.
RUN mvn -q dependency:go-offline -B || true
COPY src src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/gamo-server-0.1.0.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
