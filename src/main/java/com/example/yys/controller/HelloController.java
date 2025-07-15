package com.example.yys.controller;

import com.example.yys.service.RateLimitService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HelloController {

    private final RateLimitService rateLimitService;
    private final Counter requestCounter;
    private final Counter rateLimitedCounter;
    private final Timer requestTimer;

    @Autowired
    public HelloController(RateLimitService rateLimitService, MeterRegistry meterRegistry) {
        this.rateLimitService = rateLimitService;
        this.requestCounter = Counter.builder("http_server_requests_seconds_count")
                .description("Total number of HTTP requests")
                .tag("endpoint", "hello")
                .register(meterRegistry);
        this.rateLimitedCounter = Counter.builder("http_server_requests_rate_limited_total")
                .description("Total number of rate limited requests")
                .register(meterRegistry);
        this.requestTimer = Timer.builder("http_server_requests_seconds_sum")
                .description("Total time of HTTP requests")
                .register(meterRegistry);
    }

    @GetMapping("/hello")
    public ResponseEntity<Map<String, String>> hello() {
        Timer.Sample sample = Timer.start();
        try {
            // 检查限流
            if (!rateLimitService.tryAcquire()) {
                rateLimitedCounter.increment();
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                        .body(Map.of("error", "429 Too Many Requests"));
            }

            requestCounter.increment();
            Map<String, String> response = new HashMap<>();
            response.put("msg", "hello");
            return ResponseEntity.ok(response);
        } finally {
            sample.stop(requestTimer);
        }
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "yys-app");
        return ResponseEntity.ok(response);
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        Map<String, Object> response = new HashMap<>();
        response.put("app", "YYS Cloud Native Application");
        response.put("version", "1.0.0");
        response.put("rateLimitInfo", rateLimitService.getRateLimitInfo());
        return ResponseEntity.ok(response);
    }
}
