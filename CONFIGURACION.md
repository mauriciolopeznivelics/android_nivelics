# 🔧 Configuración del Sistema SonarQube

## 📍 **UBICACIONES DONDE AGREGAR CONFIGURACIÓN**

### 1. **GitHub Repository Secrets** (OBLIGATORIO)
**Ubicación:** `GitHub.com > Tu Repositorio > Settings > Secrets and variables > Actions`

```bash
# Agregar estos 2 secrets:
SONAR_HOST_URL = http://TU-IP-MINIKUBE:30900
SONAR_TOKEN = squ_TU_TOKEN_SONARQUBE
```

### 2. **Archivo sonar-project.properties** (OBLIGATORIO)
**Ubicación:** `Raíz de tu proyecto Android`

```properties
# Personalizar estos valores para tu proyecto:
sonar.projectKey=tu_proyecto_android
sonar.projectName=Tu Proyecto Android
sonar.sources=app/src/main/java,app/src/main/kotlin
sonar.tests=app/src/test/java,app/src/test/kotlin

# Rutas de reportes (ajustar según tu estructura):
sonar.coverage.jacoco.xmlReportPaths=app/build/reports/jacoco/testDebugUnitTestCoverage/testDebugUnitTestCoverage.xml
sonar.android.lint.report=app/build/reports/lint-results-debug.xml
```

### 3. **Variables de Entorno Locales** (Para scripts)
**Ubicación:** `Terminal / .bashrc / .env file`

```bash
# Exportar estas variables antes de ejecutar scripts:
export SONAR_HOST_URL="http://$(minikube ip):30900"
export SONAR_TOKEN="squ_tu_token_aqui"
export GITHUB_TOKEN="ghp_tu_token_aqui"
export GITHUB_REPO="tu-usuario/tu-repositorio"
```

### 4. **Configuración Gradle** (OBLIGATORIO para Android)
**Ubicación:** `app/build.gradle`

```gradle
// Agregar plugin JaCoCo
apply plugin: 'jacoco'

// Configurar JaCoCo task
task jacocoTestReport(type: JacocoReport, dependsOn: ['testDebugUnitTest']) {
    reports {
        xml.enabled = true
        html.enabled = true
        xml.destination file("${buildDir}/reports/jacoco/testDebugUnitTestCoverage/testDebugUnitTestCoverage.xml")
    }
    
    def fileFilter = [
        '**/R.class', '**/R$*.class', '**/BuildConfig.*', '**/Manifest*.*',
        '**/*Test*.*', 'android/**/*.*'
    ]
    
    def debugTree = fileTree(dir: "${buildDir}/intermediates/javac/debug", excludes: fileFilter)
    def kotlinDebugTree = fileTree(dir: "${buildDir}/tmp/kotlin-classes/debug", excludes: fileFilter)
    
    classDirectories.from = files([debugTree, kotlinDebugTree])
    sourceDirectories.from = files(['src/main/java', 'src/main/kotlin'])
    executionData.from = fileTree(dir: "$buildDir", includes: ['**/*.exec', '**/*.ec'])
}
```

## 🚀 **PASOS DE CONFIGURACIÓN COMPLETA**

### Paso 1: Configurar Minikube
```bash
# Seguir la guía completa:
cat docs/minikube-setup-ubuntu.md

# Inicio rápido:
minikube start --cpus=4 --memory=8192 --disk-size=50g
```

### Paso 2: Desplegar SonarQube
```bash
# Desplegar automáticamente:
./deploy.sh

# Obtener IP de SonarQube:
echo "SonarQube URL: http://$(minikube ip):30900"
```

### Paso 3: Configurar SonarQube
```bash
# 1. Acceder a SonarQube: http://$(minikube ip):30900
# 2. Login: admin/admin (cambiar contraseña)
# 3. Ir a: Administration > Security > Users > admin > Tokens
# 4. Generar token: "GitHub Actions Integration"
# 5. Copiar el token generado

# Configurar Quality Gates automáticamente:
export SONAR_HOST_URL="http://$(minikube ip):30900"
export SONAR_TOKEN="squ_tu_token_copiado"
./scripts/configure-quality-gate.sh
```

### Paso 4: Configurar GitHub Secrets
```bash
# En GitHub.com:
# 1. Ir a: Tu Repositorio > Settings > Secrets and variables > Actions
# 2. Click "New repository secret"
# 3. Agregar:
#    Name: SONAR_HOST_URL
#    Value: http://TU-IP-MINIKUBE:30900
# 4. Click "New repository secret"
# 5. Agregar:
#    Name: SONAR_TOKEN
#    Value: squ_tu_token_copiado
```

### Paso 5: Configurar Branch Protection
```bash
# Generar GitHub Personal Access Token:
# 1. GitHub.com > Settings > Developer settings > Personal access tokens > Tokens (classic)
# 2. Generate new token (classic)
# 3. Scopes: repo, admin:repo_hook
# 4. Copiar token generado

# Configurar Branch Protection automáticamente:
export GITHUB_TOKEN="ghp_tu_token_github"
export GITHUB_REPO="tu-usuario/tu-repositorio"
./scripts/setup-github-protection.sh
```

### Paso 6: Verificar Configuración
```bash
# Probar despliegue completo:
./scripts/test-deployment.sh

# Probar bloqueo Quality Gate:
./scripts/test-quality-gate-blocking.sh
```

## 📋 **CHECKLIST DE CONFIGURACIÓN**

### ✅ **Minikube y Kubernetes**
- [ ] Minikube iniciado con recursos suficientes
- [ ] SonarQube desplegado y accesible
- [ ] PostgreSQL funcionando
- [ ] Volúmenes persistentes creados

### ✅ **SonarQube**
- [ ] Acceso web funcionando (admin/admin)
- [ ] Contraseña cambiada
- [ ] Token de acceso generado
- [ ] Quality Gate "Android Strict" configurado

### ✅ **GitHub Repository**
- [ ] Secrets SONAR_HOST_URL y SONAR_TOKEN configurados
- [ ] Workflow .github/workflows/sonar-analysis.yml presente
- [ ] Branch Protection Rules configuradas
- [ ] Required status checks habilitados

### ✅ **Proyecto Android**
- [ ] sonar-project.properties configurado
- [ ] JaCoCo plugin agregado a build.gradle
- [ ] Pruebas unitarias con >80% cobertura
- [ ] Estructura de directorios correcta

## 🔍 **VERIFICACIÓN RÁPIDA**

### Comando para verificar todo:
```bash
# Verificar Minikube
minikube status

# Verificar SonarQube
curl -I "http://$(minikube ip):30900"

# Verificar configuración
./scripts/test-deployment.sh --quick

# Verificar GitHub integration
./scripts/setup-github-protection.sh --status
```

## 🆘 **TROUBLESHOOTING COMÚN**

### Problema: SonarQube no accesible
```bash
# Solución:
kubectl get pods -n sonarqube
kubectl logs -f deployment/sonarqube -n sonarqube
```

### Problema: GitHub Actions falla
```bash
# Verificar secrets en GitHub:
# Settings > Secrets and variables > Actions
# Debe tener: SONAR_HOST_URL y SONAR_TOKEN
```

### Problema: Quality Gate no bloquea
```bash
# Verificar Branch Protection:
./scripts/setup-github-protection.sh --status
```

## 📞 **SOPORTE**

Si tienes problemas:
1. Revisar logs: `kubectl logs -f deployment/sonarqube -n sonarqube`
2. Verificar conectividad: `curl -I http://$(minikube ip):30900`
3. Probar scripts: `./scripts/test-deployment.sh`
4. Revisar GitHub Actions logs en tu repositorio