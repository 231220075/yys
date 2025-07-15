package com.example.yys.config;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Gauge;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.atomic.AtomicInteger;

@Configuration
public class MetricsConfig {

    private final AtomicInteger activeConnections = new AtomicInteger(0);

    @Bean
    public AtomicInteger activeConnectionsGauge(MeterRegistry meterRegistry) {
        Gauge.builder("http_server_active_connections", activeConnections, AtomicInteger::get)
                .description("Number of active HTTP connections")
                .register(meterRegistry);
        return activeConnections;
    }
}
