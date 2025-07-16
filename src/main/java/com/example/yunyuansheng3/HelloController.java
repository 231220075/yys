package com.example.yunyuansheng3;

import java.util.HashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import com.google.common.util.concurrent.RateLimiter;

@RestController
public class HelloController {

    // 每秒最多允许 100 个请求
    private final RateLimiter rateLimiter = RateLimiter.create(100.0);

    @GetMapping("/hello")
    public ResponseEntity<Map<String, String>> hello() {
        // 尝试获取许可，如果获取不到，则表示限流
        if (rateLimiter.tryAcquire()) {
            Map<String, String> response = new HashMap<>();
            response.put("msg", "hello");
            return ResponseEntity.ok(response);
        } else {
            // 返回 429 Too Many Requests
            Map<String, String> errorResponse = new HashMap<>();
            errorResponse.put("msg", "Too Many Requests");
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(errorResponse);
        }
    }
}