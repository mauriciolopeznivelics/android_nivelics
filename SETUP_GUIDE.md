# 🚀 Guía Completa de Configuración SonarQube + GitHub Actions

Esta guía te llevará paso a paso para configurar el sistema completo de análisis de calidad de código que **bloquea automáticamente merges** hasta que el código pase por SonarQube.

## 📋 Requisitos Previos

- ✅ SonarQube ejecutándose en: `http://localhost:9000`
- ✅ Proyecto Android en GitHub
- ✅ Permisos de administrador en el repositorio GitHub

## 🔧 PASO 1: Configurar SonarQube

### 1.1 Acceso Inicial

1. **Abrir SonarQube en el navegador:**
   ```
   http://localhost:9000
   ```

2. **Iniciar sesión:**
   - **Usuario:** `admin`
   - **Contraseña:** `admin`

3. **Cambiar contraseña por defecto:**
   - SonarQube te pedirá cambiar la contraseña
   - Usa una contraseña segura y guárdala

### 1.2 Generar Token de Acceso

1. **Ir a configuración de usuario:**
   - Click en el avatar (esquina superior derecha)
   - Seleccionar **"My Account"**

2. **Generar token:**
   - Ir a la pestaña **"Security"**
   - En la sección **"Tokens"**
   - **Name:** `GitHub Actions Integration`
   - **Type:** `Global Analysis Token`
   - Click **"Generate"**

3. **Copiar el token:**
   ```
   squ_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
   ```
   ⚠️ **IMPORTANTE:** Guarda este token, no se mostrará de nuevo.

### 1.3 Configurar Quality Gates Automáticamente

1. **Abrir terminal en el proyecto:**
   ```bash
   # Configurar variables de entorno
   export SONAR_HOST_URL='http://localhost:9000'
   export SONAR_TOKEN='squ_tu_token_copiado_aqui'
   
   # Ejecutar configuración automática
   chmod +x scripts/configure-quality-gate.sh
   ./scripts/configure-quality-gate.sh
   ```

2. **Verificar que se creó el Quality Gate:**
   - En SonarQube: **Quality Gates** → Debe aparecer **"Android Strict"**
   - Verificar que esté marcado como **"Default"**

## 🐙 PASO 2: Configurar GitHub Repository

### 2.1 Configurar Secrets del Repositorio

1. **Ir a tu repositorio en GitHub:**
   ```
   https://github.com/tu-usuario/tu-repositorio
   ```

2. **Acceder a Settings:**
   - Click en **"Settings"** (pestaña del repositorio)
   - En el menú lateral: **"Secrets and variables"** → **"Actions"**

3. **Agregar SONAR_HOST_URL:**
   - Click **"New repository secret"**
   - **Name:** `SONAR_HOST_URL`
   - **Secret:** `http://192.168.34.214:9000`
   - Click **"Add secret"**

4. **Agregar SONAR_TOKEN:**
   - Click **"New repository secret"**
   - **Name:** `SONAR_TOKEN`
   - **Secret:** `squ_tu_token_copiado_aqui`
   - Click **"Add secret"**

### 2.2 Configurar Branch Protection Rules

#### Opción A: Configuración Automática (Recomendada)

1. **Generar GitHub Personal Access Token:**
   - Ir a: https://github.com/settings/tokens
   - Click **"Generate new token (classic)"**
   - **Scopes necesarios:**
     - ✅ `repo` (Full control of private repositories)
     - ✅ `admin:repo_hook` (Admin access to repository hooks)
   - Click **"Generate token"**
   - Copiar el token: `ghp_xxxxxxxxxxxxxxxxxxxx`

2. **Ejecutar script de configuración:**
   ```bash
   # Configurar variables
   export GITHUB_TOKEN="ghp_tu_token_github"
   export GITHUB_REPO="tu-usuario/tu-repositorio"
   
   # Ejecutar configuración
   chmod +x scripts/setup-github-protection.sh
   ./scripts/setup-github-protection.sh
   ```

#### Opción B: Configuración Manual

1. **Ir a Branch Protection:**
   - En tu repositorio: **Settings** → **Branches**
   - Click **"Add rule"** o editar regla existente

2. **Configurar regla para rama `main` (o `master`):**
   - **Branch name pattern:** `main`
   - ✅ **Require status checks to pass before merging**
   - ✅ **Require branches to be up to date before merging**
   - **Status checks required:**
     - ✅ `SonarQube Quality Gate`
     - ✅ `SonarQube Analysis`
     - ✅ `Build Android Project`
     - ✅ `Run Tests and Generate Coverage`
   - ✅ **Require pull request reviews before merging**
   - ✅ **Dismiss stale pull request approvals when new commits are pushed**
   - ✅ **Do not allow bypassing the above settings**

3. **Guardar la regla**

## 📱 PASO 3: Configurar Proyecto Android

### 3.1 Agregar Configuración SonarQube

1. **Crear archivo `sonar-project.properties` en la raíz del proyecto:**
   ```properties
   # Información del proyecto
   sonar.projectKey=tu_proyecto_android
   sonar.projectName=Tu Proyecto Android
   sonar.projectVersion=1.0
   
   # Configuración de código fuente
   sonar.sources=app/src/main/java,app/src/main/kotlin
   sonar.tests=app/src/test/java,app/src/test/kotlin
   
   # Configuración de cobertura JaCoCo
   sonar.coverage.jacoco.xmlReportPaths=app/build/reports/jacoco/testDebugUnitTestCoverage/testDebugUnitTestCoverage.xml
   
   # Configuración Android Lint
   sonar.android.lint.report=app/build/reports/lint-results-debug.xml
   
   # Binarios Java/Kotlin
   sonar.java.binaries=app/build/intermediates/javac,app/build/tmp/kotlin-classes
   sonar.java.libraries=app/build/intermediates/compile_and_runtime_not_namespaced_r_class_jar
   
   # Configuración de idioma
   sonar.language=kotlin
   sonar.sourceEncoding=UTF-8
   
   # Exclusiones de archivos generados
   sonar.coverage.exclusions=**/R.java,**/R$*.java,**/BuildConfig.*,**/Manifest*.*,**/*Test*.*,**/databinding/**,**/generated/**
   ```

### 3.2 Configurar Gradle para JaCoCo

1. **Editar `app/build.gradle`:**
   ```gradle
   android {
       // ... configuración existente
       
       testOptions {
           unitTests.all {
               useJUnitPlatform()
               finalizedBy jacocoTestReport
           }
       }
   }
   
   // Agregar plugin JaCoCo
   apply plugin: 'jacoco'
   
   // Configurar tarea JaCoCo
   task jacocoTestReport(type: JacocoReport, dependsOn: ['testDebugUnitTest']) {
       reports {
           xml.enabled = true
           html.enabled = true
           xml.destination file("${buildDir}/reports/jacoco/testDebugUnitTestCoverage/testDebugUnitTestCoverage.xml")
       }
       
       def fileFilter = [
           '**/R.class', '**/R$*.class', '**/BuildConfig.*', '**/Manifest*.*',
           '**/*Test*.*', 'android/**/*.*', '**/databinding/**', '**/generated/**'
       ]
       
       def debugTree = fileTree(dir: "${buildDir}/intermediates/javac/debug", excludes: fileFilter)
       def kotlinDebugTree = fileTree(dir: "${buildDir}/tmp/kotlin-classes/debug", excludes: fileFilter)
       
       classDirectories.from = files([debugTree, kotlinDebugTree])
       sourceDirectories.from = files(['src/main/java', 'src/main/kotlin'])
       executionData.from = fileTree(dir: "$buildDir", includes: ['**/*.exec', '**/*.ec'])
   }
   
   // Asegurar que JaCoCo se ejecute después de las pruebas
   tasks.withType(Test) {
       finalizedBy jacocoTestReport
   }
   ```

### 3.3 Copiar Workflow de GitHub Actions

1. **Crear directorio `.github/workflows/` si no existe**

2. **Copiar el archivo del workflow:**
   ```bash
   cp .github/workflows/sonar-analysis.yml tu-proyecto/.github/workflows/
   ```

   O crear manualmente el archivo `.github/workflows/sonar-analysis.yml` con el contenido del workflow.

## 🧪 PASO 4: Probar el Sistema

### 4.1 Crear Pull Request de Prueba

1. **Crear una nueva rama:**
   ```bash
   git checkout -b test-sonarqube-integration
   ```

2. **Hacer un cambio menor en el código**

3. **Commit y push:**
   ```bash
   git add .
   git commit -m "Test: SonarQube integration"
   git push origin test-sonarqube-integration
   ```

4. **Crear Pull Request en GitHub**

### 4.2 Verificar que el Pipeline se Ejecuta

1. **Ir a la pestaña "Actions" en GitHub**
2. **Verificar que se ejecuta el workflow "Android CI/CD with SonarQube"**
3. **Observar los jobs:**
   - ✅ Build Android Project
   - ✅ Run Tests and Generate Coverage
   - ✅ SonarQube Analysis
   - ✅ Quality Gate Validation

### 4.3 Verificar Bloqueo de Merge

1. **Si el código tiene buena calidad (>80% cobertura, sin bugs críticos):**
   - ✅ Status checks aparecen en verde
   - ✅ Botón "Merge" está habilitado

2. **Si el código no cumple estándares:**
   - ❌ Status checks aparecen en rojo
   - ❌ Botón "Merge" está deshabilitado
   - ❌ Mensaje: "Merge blocked by failing required status checks"

## 🔍 PASO 5: Verificar Configuración

### 5.1 Verificar SonarQube

1. **Acceder a SonarQube:** `http://localhost:9000`
2. **Verificar que aparece tu proyecto**
3. **Verificar Quality Gate "Android Strict" como default**
4. **Revisar métricas del proyecto**

### 5.2 Verificar GitHub Actions

1. **Ir a repositorio → Settings → Secrets and variables → Actions**
2. **Verificar que existen:**
   - ✅ `SONAR_HOST_URL`
   - ✅ `SONAR_TOKEN`

### 5.3 Verificar Branch Protection

1. **Ir a repositorio → Settings → Branches**
2. **Verificar regla para rama principal**
3. **Verificar status checks requeridos**

### 5.4 Ejecutar Script de Validación

```bash
# Ejecutar script de validación completa
chmod +x scripts/test-deployment.sh
./scripts/test-deployment.sh

# Verificar configuración GitHub
./scripts/setup-github-protection.sh --status
```

## 🚨 Troubleshooting

### Problema: SonarQube no accesible

**Solución:**
```bash
# Verificar que el contenedor esté ejecutándose
docker ps | grep sonarqube

# Si no está ejecutándose, iniciarlo
docker start $(docker ps -a | grep sonarqube | awk '{print $1}')

# Verificar acceso
curl -I http://localhost:9000
```

### Problema: GitHub Actions falla

**Verificar:**
1. ✅ Secrets configurados correctamente
2. ✅ Archivo `sonar-project.properties` existe
3. ✅ Configuración JaCoCo en `build.gradle`
4. ✅ SonarQube accesible desde GitHub Actions

### Problema: Quality Gate no bloquea

**Verificar:**
1. ✅ Branch Protection Rules configuradas
2. ✅ Status checks requeridos incluyen "SonarQube Quality Gate"
3. ✅ Quality Gate "Android Strict" es el default en SonarQube

### Problema: Cobertura baja

**Solución:**
1. Agregar más pruebas unitarias
2. Verificar exclusiones en `sonar-project.properties`
3. Verificar configuración JaCoCo

## 📊 Métricas del Quality Gate

El sistema bloquea merges si:

- ❌ **Cobertura < 80%**
- ❌ **Bugs críticos > 0**
- ❌ **Vulnerabilidades altas > 0**
- ❌ **Code Smells blocker > 0**
- ❌ **Líneas duplicadas > 3%**
- ❌ **Ratings de calidad < A**

## 🎉 ¡Sistema Configurado!

Una vez completados todos los pasos:

✅ **SonarQube analiza automáticamente cada commit**
✅ **GitHub bloquea merges que no cumplan estándares**
✅ **Solo código de alta calidad llega a producción**
✅ **Desarrolladores reciben feedback inmediato**

## 📞 Soporte

Si tienes problemas:

1. **Revisar logs de GitHub Actions**
2. **Verificar logs de SonarQube**
3. **Ejecutar scripts de validación**
4. **Consultar la documentación en README.md**

---

**🔒 Sistema que garantiza calidad de código mediante bloqueo automático de merges hasta que el código cumpla con los estándares de SonarQube.**