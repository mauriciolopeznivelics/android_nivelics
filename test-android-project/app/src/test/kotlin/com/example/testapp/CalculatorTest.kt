package com.example.testapp

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4

/**
 * Unit tests for Calculator class
 * These tests provide good code coverage to pass SonarQube Quality Gate
 */
@RunWith(JUnit4::class)
class CalculatorTest {
    
    private lateinit var calculator: Calculator
    
    @Before
    fun setUp() {
        calculator = Calculator()
    }
    
    @Test
    fun testAdd() {
        assertEquals(5, calculator.add(2, 3))
        assertEquals(0, calculator.add(-5, 5))
        assertEquals(-8, calculator.add(-3, -5))
        assertEquals(100, calculator.add(50, 50))
    }
    
    @Test
    fun testSubtract() {
        assertEquals(2, calculator.subtract(5, 3))
        assertEquals(-10, calculator.subtract(-5, 5))
        assertEquals(2, calculator.subtract(-3, -5))
        assertEquals(0, calculator.subtract(50, 50))
    }
    
    @Test
    fun testMultiply() {
        assertEquals(15, calculator.multiply(3, 5))
        assertEquals(-25, calculator.multiply(-5, 5))
        assertEquals(15, calculator.multiply(-3, -5))
        assertEquals(0, calculator.multiply(0, 50))
    }
    
    @Test
    fun testDivide() {
        assertEquals(2.5, calculator.divide(5, 2), 0.001)
        assertEquals(-1.0, calculator.divide(-5, 5), 0.001)
        assertEquals(0.6, calculator.divide(-3, -5), 0.001)
        assertEquals(1.0, calculator.divide(50, 50), 0.001)
    }
    
    @Test(expected = IllegalArgumentException::class)
    fun testDivideByZero() {
        calculator.divide(5, 0)
    }
    
    @Test
    fun testPower() {
        assertEquals(8.0, calculator.power(2.0, 3.0), 0.001)
        assertEquals(1.0, calculator.power(5.0, 0.0), 0.001)
        assertEquals(0.25, calculator.power(2.0, -2.0), 0.001)
        assertEquals(4.0, calculator.power(16.0, 0.5), 0.001)
    }
    
    @Test
    fun testSqrt() {
        assertEquals(3.0, calculator.sqrt(9.0), 0.001)
        assertEquals(0.0, calculator.sqrt(0.0), 0.001)
        assertEquals(2.236, calculator.sqrt(5.0), 0.001)
        assertEquals(10.0, calculator.sqrt(100.0), 0.001)
    }
    
    @Test(expected = IllegalArgumentException::class)
    fun testSqrtNegative() {
        calculator.sqrt(-4.0)
    }
    
    @Test
    fun testFactorial() {
        assertEquals(1L, calculator.factorial(0))
        assertEquals(1L, calculator.factorial(1))
        assertEquals(2L, calculator.factorial(2))
        assertEquals(6L, calculator.factorial(3))
        assertEquals(24L, calculator.factorial(4))
        assertEquals(120L, calculator.factorial(5))
        assertEquals(720L, calculator.factorial(6))
    }
    
    @Test(expected = IllegalArgumentException::class)
    fun testFactorialNegative() {
        calculator.factorial(-1)
    }
    
    @Test
    fun testIsPrime() {
        assertFalse(calculator.isPrime(-5))
        assertFalse(calculator.isPrime(0))
        assertFalse(calculator.isPrime(1))
        assertTrue(calculator.isPrime(2))
        assertTrue(calculator.isPrime(3))
        assertFalse(calculator.isPrime(4))
        assertTrue(calculator.isPrime(5))
        assertFalse(calculator.isPrime(6))
        assertTrue(calculator.isPrime(7))
        assertFalse(calculator.isPrime(8))
        assertFalse(calculator.isPrime(9))
        assertFalse(calculator.isPrime(10))
        assertTrue(calculator.isPrime(11))
        assertTrue(calculator.isPrime(13))
        assertTrue(calculator.isPrime(17))
        assertTrue(calculator.isPrime(19))
        assertFalse(calculator.isPrime(20))
        assertFalse(calculator.isPrime(25))
        assertTrue(calculator.isPrime(29))
        assertFalse(calculator.isPrime(100))
    }
    
    @Test
    fun testGcd() {
        assertEquals(5, calculator.gcd(10, 15))
        assertEquals(1, calculator.gcd(7, 13))
        assertEquals(6, calculator.gcd(12, 18))
        assertEquals(12, calculator.gcd(12, 0))
        assertEquals(7, calculator.gcd(0, 7))
        assertEquals(4, calculator.gcd(-8, 12))
        assertEquals(3, calculator.gcd(9, -6))
        assertEquals(5, calculator.gcd(-10, -15))
    }
    
    @Test
    fun testComplexCalculations() {
        // Test combining multiple operations
        val result1 = calculator.add(calculator.multiply(2, 3), calculator.divide(8, 2).toInt())
        assertEquals(10, result1)
        
        val result2 = calculator.subtract(calculator.power(2.0, 3.0).toInt(), calculator.factorial(3).toInt())
        assertEquals(2, result2)
        
        // Test edge cases
        assertEquals(0, calculator.multiply(0, 1000))
        assertEquals(1.0, calculator.divide(100, 100), 0.001)
        assertTrue(calculator.isPrime(2))
        assertFalse(calculator.isPrime(4))
    }
}