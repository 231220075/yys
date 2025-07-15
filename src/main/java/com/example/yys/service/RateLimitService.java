package com.example.yys.service;

import com.google.common.util.concurrent.RateLimiter;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

@Service
public class RateLimitService {

    // 使用Guava RateLimiter，每秒允许100个请求
    private final RateLimiter guavaRateLimiter;
    
    // 使用Bucket4j，作为备选方案
    private final Bucket bucket;

    public RateLimitService() {
        // 初始化Guava RateLimiter，每秒100个请求
        this.guavaRateLimiter = RateLimiter.create(100.0);
        
        // 初始化Bucket4j，每秒100个令牌，突发容量200
        Bandwidth limit = Bandwidth.builder()
                .capacity(200)
                .refillIntervally(100, Duration.ofSeconds(1))
                .build();
        this.bucket = Bucket.builder()
                .addLimit(limit)
                .build();
    }

    /**
     * 尝试获取许可（使用Guava RateLimiter）
     */
    public boolean tryAcquire() {
        return guavaRateLimiter.tryAcquire();
    }

    /**
     * 尝试获取许可（使用Bucket4j）
     */
    public boolean tryAcquireWithBucket() {
        return bucket.tryConsume(1);
    }

    /**
     * 获取限流信息
     */
    public Map<String, Object> getRateLimitInfo() {
        Map<String, Object> info = new HashMap<>();
        info.put("rateLimit", "100 requests per second");
        info.put("implementation", "Google Guava RateLimiter");
        info.put("burstCapacity", "200 tokens (Bucket4j alternative)");
        info.put("availableTokens", bucket.getAvailableTokens());
        return info;
    }
}
