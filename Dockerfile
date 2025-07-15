# 使用 Maven 镜像作为构建阶段
FROM maven:3.8.5-openjdk-17 AS builder

# 设置工作目录
WORKDIR /app

# 复制 pom.xml 文件并下载依赖
COPY pom.xml .
RUN mvn dependency:go-offline -B

# 复制项目源代码
COPY src ./src

# 打包 Spring Boot 应用
RUN mvn clean package -DskipTests

# 使用 OpenJDK 镜像作为运行阶段
FROM openjdk:17-jre-slim

# 设置工作目录
WORKDIR /app

# 从构建阶段复制打包好的 jar 文件
COPY --from=builder /app/target/*.jar app.jar

# 暴露应用端口
EXPOSE 8080

# 运行 Spring Boot 应用
ENTRYPOINT ["java","-jar","app.jar"]