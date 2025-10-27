#!/bin/bash

# Script para configurar Quality Gate en SonarCloud
# Requiere SONAR_TOKEN configurado

set -e

SONAR_HOST_URL="https://sonarcloud.io"
PROJECT_KEY="mauriciolopeznivelics_android_nivelics"
ORGANIZATION="mauriciolopeznivelics"

echo "🔧 Configurando Quality Gate para coverage 80%..."

# Verificar que el token esté configurado
if [ -z "$SONAR_TOKEN" ]; then
    echo "❌ Error: SONAR_TOKEN no está configurado"
    echo "Configura el token: export SONAR_TOKEN=tu_token"
    exit 1
fi

# Crear Quality Gate personalizado
echo "📋 Creando Quality Gate personalizado..."
GATE_RESPONSE=$(curl -s -u "$SONAR_TOKEN:" \
    -X POST \
    "$SONAR_HOST_URL/api/qualitygates/create" \
    -d "name=Android Project Gate")

GATE_ID=$(echo "$GATE_RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)

if [ -z "$GATE_ID" ]; then
    echo "⚠️  Quality Gate ya existe o error en creación"
    # Buscar Quality Gate existente
    GATES_LIST=$(curl -s -u "$SONAR_TOKEN:" \
        "$SONAR_HOST_URL/api/qualitygates/list")
    GATE_ID=$(echo "$GATES_LIST" | grep -A5 "Android Project Gate" | grep -o '"id":[0-9]*' | cut -d':' -f2)
fi

echo "🎯 Quality Gate ID: $GATE_ID"

# Configurar condición de Coverage >= 80%
echo "📊 Configurando Coverage >= 80%..."
curl -s -u "$SONAR_TOKEN:" \
    -X POST \
    "$SONAR_HOST_URL/api/qualitygates/create_condition" \
    -d "gateId=$GATE_ID" \
    -d "metric=coverage" \
    -d "op=LT" \
    -d "error=80"

# Configurar otras condiciones
echo "🔍 Configurando condiciones adicionales..."

# Duplicated Lines < 3%
curl -s -u "$SONAR_TOKEN:" \
    -X POST \
    "$SONAR_HOST_URL/api/qualitygates/create_condition" \
    -d "gateId=$GATE_ID" \
    -d "metric=duplicated_lines_density" \
    -d "op=GT" \
    -d "error=3"

# Maintainability Rating = A
curl -s -u "$SONAR_TOKEN:" \
    -X POST \
    "$SONAR_HOST_URL/api/qualitygates/create_condition" \
    -d "gateId=$GATE_ID" \
    -d "metric=sqale_rating" \
    -d "op=GT" \
    -d "error=1"

# Reliability Rating = A
curl -s -u "$SONAR_TOKEN:" \
    -X POST \
    "$SONAR_HOST_URL/api/qualitygates/create_condition" \
    -d "gateId=$GATE_ID" \
    -d "metric=reliability_rating" \
    -d "op=GT" \
    -d "error=1"

# Security Rating = A
curl -s -u "$SONAR_TOKEN:" \
    -X POST \
    "$SONAR_HOST_URL/api/qualitygates/create_condition" \
    -d "gateId=$GATE_ID" \
    -d "metric=security_rating" \
    -d "op=GT" \
    -d "error=1"

# Asignar Quality Gate al proyecto
echo "🔗 Asignando Quality Gate al proyecto..."
curl -s -u "$SONAR_TOKEN:" \
    -X POST \
    "$SONAR_HOST_URL/api/qualitygates/select" \
    -d "gateId=$GATE_ID" \
    -d "projectKey=$PROJECT_KEY"

echo "✅ Quality Gate configurado exitosamente!"
echo "🔗 Ver en: $SONAR_HOST_URL/organizations/$ORGANIZATION/quality_gates"
echo "📊 Proyecto: $SONAR_HOST_URL/project/overview?id=$PROJECT_KEY"