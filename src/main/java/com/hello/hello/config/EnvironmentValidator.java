package com.hello.hello.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class EnvironmentValidator implements CommandLineRunner {
    
    @Override
    public void run(String... args) throws Exception {
        System.out.println("=== Environment Variables Debug ===");
        System.out.println("REDIS_HOST: " + System.getenv("REDIS_HOST"));
        System.out.println("REDIS_PORT: " + System.getenv("REDIS_PORT"));
        System.out.println("All environment variables:");
        System.getenv().entrySet().stream()
            .filter(entry -> entry.getKey().startsWith("REDIS"))
            .forEach(entry -> System.out.println(entry.getKey() + "=" + entry.getValue()));
        System.out.println("================================");
    }
}
