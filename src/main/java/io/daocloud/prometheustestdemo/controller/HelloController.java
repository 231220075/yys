package io.daocloud.prometheustestdemo.controller;

import com.google.common.util.concurrent.RateLimiter;
import io.micrometer.core.annotation.Timed;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.annotation.PostConstruct;
import java.util.HashMap;
import java.util.Map;

/**
 * REST API 控制器
 * 实现 /hello 接口，限流功能和 Prometheus 指标
 */
@RestController
@Slf4j
public class HelloController {
    private final RateLimiter rateLimiter = RateLimiter.create(100.0);
    
    @Autowired
    private MeterRegistry meterRegistry;
    private Counter requestCounter;
    private Counter rateLimitedCounter;

    @PostConstruct
    public void init() {
        // 初始化自定义指标
        requestCounter = Counter.builder("http_requests_total")
                .description("Total number of HTTP requests")
                .tag("endpoint", "/hello")
                .register(meterRegistry);
                
        rateLimitedCounter = Counter.builder("rate_limited_requests_total")
                .description("Total number of rate limited requests")
                .tag("endpoint", "/hello")
                .register(meterRegistry);
    }

    @GetMapping("/hello")
    @Timed(value = "http_request_duration_seconds", description = "HTTP request duration")
    public ResponseEntity<Map<String, Object>> hello() {
        if (!rateLimiter.tryAcquire()) {
            // 记录被限流的请求
            rateLimitedCounter.increment();
            System.out.println("Request rate limited for /hello endpoint");
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "Too Many Requests");
            errorResponse.put("message", "Rate limit exceeded. Maximum 100 requests per second allowed.");
            errorResponse.put("timestamp", System.currentTimeMillis());
            
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(errorResponse);
        }

        // 记录成功的请求
        requestCounter.increment();
        System.out.println("Processing /hello request");

        // 返回固定的 JSON 数据
        Map<String, Object> response = new HashMap<>();
        response.put("msg", "hello");
        response.put("timestamp", System.currentTimeMillis());
        response.put("service", "prometheus-test-demo");
        response.put("version", "1.0.0");
        
        return ResponseEntity.ok(response);
    }

    /**
     * 健康检查接口
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> status = new HashMap<>();
        status.put("status", "UP");
        status.put("service", "prometheus-test-demo");
        return ResponseEntity.ok(status);
    }
}
