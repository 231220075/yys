package com.hello.hello.service;

import java.time.Duration;
import java.util.function.Supplier;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.BucketConfiguration;
import io.github.bucket4j.Refill;
import io.github.bucket4j.distributed.proxy.ProxyManager;

@Service
public class RateLimiterService {

    private final ProxyManager<byte[]> buckets;
    private static final byte[] KEY = "global-rate-limit-key".getBytes();

    @Autowired
    public RateLimiterService(ProxyManager<byte[]> buckets) {
        this.buckets = buckets;
    }

    public Bucket resolveBucket() {
        return buckets.builder().build(KEY, getConfigSupplier());
    }

    private Supplier<BucketConfiguration> getConfigSupplier() {
        return () -> BucketConfiguration.builder()
                .addLimit(Bandwidth.classic(
                    100, 
                    Refill.greedy(100, Duration.ofSeconds(1)))
                )
                .build();
    }
}
