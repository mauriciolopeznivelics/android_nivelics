#!/bin/bash

# SonarQube Analysis Script for Android Projects
# This script handles the SonarQube analysis with proper error handling and logging

set -e

echo "🔍 Starting SonarQube Analysis for Android Project"

# Configuration
PROJECT_KEY="android_app"
PROJECT_NAME="AndroidApp"
PROJECT_VERSION="${CI_COMMIT_SHORT_SHA:-1.0}"
BRANCH_NAME="${CI_COMMIT_REF_NAME:-master}"

# Validate required environment variables
if [ -z "$SONAR_HOST_URL" ]; then
    echo "❌ Error: SONAR_HOST_URL environment variable is not set"
    exit 1
fi

if [ -z "$SONAR_TOKEN" ]; then
    echo "❌ Error: SONAR_TOKEN environment variable is not set"
    exit 1
fi

echo "📋 Analysis Configuration:"
echo "  - Project Key: $PROJECT_KEY"
echo "  - Project Name: $PROJECT_NAME"
echo "  - Project Version: $PROJECT_VERSION"
echo "  - Branch: $BRANCH_NAME"
echo "  - SonarQube Host: $SONAR_HOST_URL"

# Check if coverage reports exist
JACOCO_REPORT="app/build/reports/jacoco/testDebugUnitTestCoverage/testDebugUnitTestCoverage.xml"
LINT_REPORT="app/build/reports/lint-results-debug.xml"

echo "📊 Checking for reports:"
if [ -f "$JACOCO_REPORT" ]; then
    echo "  ✅ JaCoCo coverage report found: $JACOCO_REPORT"
else
    echo "  ⚠️  JaCoCo coverage report not found: $JACOCO_REPORT"
fi

if [ -f "$LINT_REPORT" ]; then
    echo "  ✅ Android Lint report found: $LINT_REPORT"
else
    echo "  ⚠️  Android Lint report not found: $LINT_REPORT"
fi

# Prepare SonarQube analysis parameters
SONAR_PARAMS=(
    "-Dsonar.projectKey=$PROJECT_KEY"
    "-Dsonar.projectName=$PROJECT_NAME"
    "-Dsonar.projectVersion=$PROJECT_VERSION"
    "-Dsonar.sources=app/src/main/java,app/src/main/kotlin"
    "-Dsonar.tests=app/src/test/java,app/src/test/kotlin"
    "-Dsonar.host.url=$SONAR_HOST_URL"
    "-Dsonar.login=$SONAR_TOKEN"
    "-Dsonar.java.binaries=app/build/intermediates/javac,app/build/tmp/kotlin-classes"
    "-Dsonar.sourceEncoding=UTF-8"
    "-Dsonar.language=kotlin"
)

# Add coverage report if exists
if [ -f "$JACOCO_REPORT" ]; then
    SONAR_PARAMS+=("-Dsonar.coverage.jacoco.xmlReportPaths=$JACOCO_REPORT")
fi

# Add lint report if exists
if [ -f "$LINT_REPORT" ]; then
    SONAR_PARAMS+=("-Dsonar.android.lint.report=$LINT_REPORT")
fi

# Add branch information for non-master branches
if [ "$BRANCH_NAME" != "master" ] && [ "$BRANCH_NAME" != "main" ]; then
    SONAR_PARAMS+=("-Dsonar.branch.name=$BRANCH_NAME")
fi

echo "🚀 Executing SonarQube analysis..."
echo "Command: sonar-scanner ${SONAR_PARAMS[*]}"

# Execute SonarQube analysis
if sonar-scanner "${SONAR_PARAMS[@]}"; then
    echo "✅ SonarQube analysis completed successfully"
    echo "📊 Analysis results will be available at: $SONAR_HOST_URL/dashboard?id=$PROJECT_KEY"
else
    echo "❌ SonarQube analysis failed"
    exit 1
fi

echo "🎉 SonarQube analysis stage completed!"