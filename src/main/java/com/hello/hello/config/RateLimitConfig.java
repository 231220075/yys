package com.hello.hello.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.github.bucket4j.redis.jedis.cas.JedisBasedProxyManager;
import redis.clients.jedis.JedisPool;

@Configuration
public class RateLimitConfig {
    
    @Bean
    public JedisBasedProxyManager<byte[]> proxyManager(JedisPool jedisPool) {
        return JedisBasedProxyManager.builderFor(jedisPool)
            .build(); // 删除过期策略配置（新版本默认自动续期）
    }
}