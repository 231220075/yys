package com.hello.hello.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.jedis.JedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;

import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

@Configuration
public class RedisConfig {
    
    @Value("${REDIS_HOST:${spring.redis.host:localhost}}")
    private String redisHost;
    
    @Value("${REDIS_PORT:${spring.redis.port:6379}}")
    private int redisPort;
    
    @Bean
    @Primary
    public RedisConnectionFactory redisConnectionFactory() {
        // 直接从环境变量读取
        String host = System.getenv("REDIS_HOST");
        if (host == null || host.trim().isEmpty()) {
            host = redisHost;
        }
        
        String portStr = System.getenv("REDIS_PORT");
        int port = redisPort;
        if (portStr != null && !portStr.trim().isEmpty()) {
            try {
                port = Integer.parseInt(portStr);
            } catch (NumberFormatException e) {
                // 使用默认端口
            }
        }
        
        System.out.println("Spring Data Redis connecting to: " + host + ":" + port);
        
        RedisStandaloneConfiguration config = new RedisStandaloneConfiguration();
        config.setHostName(host);
        config.setPort(port);
        
        JedisConnectionFactory factory = new JedisConnectionFactory(config);
        return factory;
    }
    
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        return template;
    }
    
    @Bean
    public JedisPool jedisPool() {
        // 直接从环境变量读取，如果为空则使用配置文件
        String host = System.getenv("REDIS_HOST");
        if (host == null || host.trim().isEmpty()) {
            host = redisHost;
        }
        
        String portStr = System.getenv("REDIS_PORT");
        int port = redisPort;
        if (portStr != null && !portStr.trim().isEmpty()) {
            try {
                port = Integer.parseInt(portStr);
            } catch (NumberFormatException e) {
                // 使用默认端口
            }
        }
        
        System.out.println("Jedis Pool connecting to: " + host + ":" + port);
        
        JedisPoolConfig config = new JedisPoolConfig();
        config.setMaxTotal(8);
        config.setMaxIdle(8);
        config.setMinIdle(0);
        config.setTestOnBorrow(true);
        config.setTestOnReturn(true);
        config.setTestWhileIdle(true);
        return new JedisPool(config, host, port);
    }
}