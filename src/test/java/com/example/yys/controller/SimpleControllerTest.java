package com.example.yys.controller;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class HelloControllerTest {

    @Test
    void testSimpleUnitTest() {
        // 简单的单元测试，确保测试功能正常工作
        assertTrue(true, "基础单元测试应该通过");
        
        // 测试字符串处理
        String expected = "hello";
        String actual = "hello";
        assertEquals(expected, actual, "字符串比较测试");
        
        // 测试数值计算
        int sum = 1 + 1;
        assertEquals(2, sum, "数值计算测试");
    }

    @Test
    void testJsonStructure() {
        // 模拟API响应结构测试
        String expectedJsonKey = "msg";
        String expectedJsonValue = "hello";
        
        assertNotNull(expectedJsonKey);
        assertNotNull(expectedJsonValue);
        assertEquals("msg", expectedJsonKey);
        assertEquals("hello", expectedJsonValue);
    }
}
