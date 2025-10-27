package com.example.testapp

/**
 * Simple calculator class for testing SonarQube integration
 * This class demonstrates various code quality scenarios
 */
class Calculator {
    
    /**
     * Adds two numbers
     * @param a First number
     * @param b Second number
     * @return Sum of a and b
     */
    fun add(a: Int, b: Int): Int {
        return a + b
    }
    
    /**
     * Subtracts two numbers
     * @param a First number
     * @param b Second number
     * @return Difference of a and b
     */
    fun subtract(a: Int, b: Int): Int {
        return a - b
    }
    
    /**
     * Multiplies two numbers
     * @param a First number
     * @param b Second number
     * @return Product of a and b
     */
    fun multiply(a: Int, b: Int): Int {
        return a * b
    }
    
    /**
     * Divides two numbers
     * @param a Dividend
     * @param b Divisor
     * @return Quotient of a and b
     * @throws IllegalArgumentException if divisor is zero
     */
    fun divide(a: Int, b: Int): Double {
        if (b == 0) {
            throw IllegalArgumentException("Division by zero is not allowed")
        }
        return a.toDouble() / b.toDouble()
    }
    
    /**
     * Calculates the power of a number
     * @param base Base number
     * @param exponent Exponent
     * @return base raised to the power of exponent
     */
    fun power(base: Double, exponent: Double): Double {
        return Math.pow(base, exponent)
    }
    
    /**
     * Calculates the square root of a number
     * @param number Input number
     * @return Square root of the number
     * @throws IllegalArgumentException if number is negative
     */
    fun sqrt(number: Double): Double {
        if (number < 0) {
            throw IllegalArgumentException("Cannot calculate square root of negative number")
        }
        return Math.sqrt(number)
    }
    
    /**
     * Calculates the factorial of a number
     * @param n Input number
     * @return Factorial of n
     * @throws IllegalArgumentException if n is negative
     */
    fun factorial(n: Int): Long {
        if (n < 0) {
            throw IllegalArgumentException("Factorial is not defined for negative numbers")
        }
        if (n == 0 || n == 1) {
            return 1
        }
        var result = 1L
        for (i in 2..n) {
            result *= i
        }
        return result
    }
    
    /**
     * Checks if a number is prime
     * @param number Input number
     * @return true if number is prime, false otherwise
     */
    fun isPrime(number: Int): Boolean {
        if (number <= 1) {
            return false
        }
        if (number <= 3) {
            return true
        }
        if (number % 2 == 0 || number % 3 == 0) {
            return false
        }
        
        var i = 5
        while (i * i <= number) {
            if (number % i == 0 || number % (i + 2) == 0) {
                return false
            }
            i += 6
        }
        return true
    }
    
    /**
     * Calculates the greatest common divisor of two numbers
     * @param a First number
     * @param b Second number
     * @return GCD of a and b
     */
    fun gcd(a: Int, b: Int): Int {
        var num1 = Math.abs(a)
        var num2 = Math.abs(b)
        
        while (num2 != 0) {
            val temp = num2
            num2 = num1 % num2
            num1 = temp
        }
        return num1
    }
}