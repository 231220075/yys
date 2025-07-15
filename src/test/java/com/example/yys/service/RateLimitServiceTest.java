package com.example.yys.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class RateLimitServiceTest {

    @Test
    void testRateLimitService() {
        RateLimitService service = new RateLimitService();
        
        // 测试正常获取许可
        assertTrue(service.tryAcquire());
        
        // 测试限流信息
        var info = service.getRateLimitInfo();
        assertNotNull(info);
        assertTrue(info.containsKey("rateLimit"));
    }

    @Test
    void testBucket4jRateLimit() {
        RateLimitService service = new RateLimitService();
        
        // 测试Bucket4j限流
        assertTrue(service.tryAcquireWithBucket());
        
        // 快速消耗令牌测试限流
        boolean rateLimited = false;
        for (int i = 0; i < 250; i++) {
            if (!service.tryAcquireWithBucket()) {
                rateLimited = true;
                break;
            }
        }
        assertTrue(rateLimited, "应该触发限流");
    }
}
