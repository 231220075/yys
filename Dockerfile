# 多阶段构建
FROM maven:3.9.4-openjdk-17 AS builder

WORKDIR /app
COPY pom.xml .
COPY src ./src

# 构建应用
RUN mvn clean package -DskipTests

# 运行时镜像
FROM openjdk:17-jre-slim

WORKDIR /app

# 添加非root用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 复制jar文件
COPY --from=builder /app/target/yys-app-1.0.0.jar app.jar

# 修改文件所有者
RUN chown appuser:appuser app.jar

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# 启动应用
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
