package com.hello.hello.controller;

import java.util.Collections;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
    
    @GetMapping("/hello")
    public Map<String, String> hello() {
        return Collections.singletonMap("msg", "hello");
    }
    
    @GetMapping("/")
    public Map<String, String> home() {
        return Collections.singletonMap("status", "Prometheus Test Demo is running!");
    }
    
    @GetMapping("/health")
    public Map<String, String> health() {
        return Collections.singletonMap("status", "UP");
    }
}