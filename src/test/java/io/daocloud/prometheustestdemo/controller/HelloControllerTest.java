package io.daocloud.prometheustestdemo.controller;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * HelloController 测试类
 */
@RunWith(SpringRunner.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class HelloControllerTest {

    @Autowired
    private WebApplicationContext webApplicationContext;

    private MockMvc mockMvc;

    @Before
    public void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).build();
    }

    /**
     * 测试 /hello 接口正常响应
     */
    @Test
    public void testHelloEndpoint() throws Exception {
        mockMvc.perform(get("/hello"))
                .andExpect(status().isOk())
                .andExpect(content().contentType("application/json;charset=UTF-8"))
                .andExpect(jsonPath("$.msg").value("hello"))
                .andExpect(jsonPath("$.service").value("prometheus-test-demo"))
                .andExpect(jsonPath("$.version").value("1.0.0"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    /**
     * 测试健康检查接口
     */
    @Test
    public void testHealthEndpoint() throws Exception {
        mockMvc.perform(get("/health"))
                .andExpect(status().isOk())
                .andExpect(content().contentType("application/json;charset=UTF-8"))
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.service").value("prometheus-test-demo"));
    }

    /**
     * 测试限流功能
     * 注意：这个测试可能需要调整，因为限流器允许每秒100个请求
     */
    @Test
    public void testRateLimiting() throws Exception {
        // 快速发送多个请求来测试限流
        int successCount = 0;
        int rateLimitedCount = 0;

        for (int i = 0; i < 150; i++) {
            MvcResult result = mockMvc.perform(get("/hello")).andReturn();
            int status = result.getResponse().getStatus();
            
            if (status == 200) {
                successCount++;
            } else if (status == 429) {
                rateLimitedCount++;
            }
        }

        System.out.println("Success requests: " + successCount);
        System.out.println("Rate limited requests: " + rateLimitedCount);
        
        // 验证有一些请求被限流了
        assert(rateLimitedCount > 0);
    }
}
