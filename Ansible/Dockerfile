FROM openjdk:8-jdk-alpine
WORKDIR /app
ADD /target/demoapp-1.0.jar app.jar
ENTRYPOINT [ "java","-jar", "app.jar"]
EXPOSE 8080
