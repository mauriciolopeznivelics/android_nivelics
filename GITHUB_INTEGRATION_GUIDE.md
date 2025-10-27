# 🐙 Guía Paso a Paso: Integración GitHub + SonarQube

## 🎯 Objetivo
Configurar tu proyecto Android para que **GitHub bloquee automáticamente merges** hasta que el código pase por SonarQube con 80% cobertura y cero bugs críticos.

## ✅ **ESTADO ACTUAL DEL SISTEMA**

- ✅ **SonarQube ejecutándose:** `http://localhost:9000`
- ✅ **Workflow actualizado:** Sin errores de deprecación
- ✅ **Scripts listos:** Para configuración automática

## 🚀 **CONFIGURACIÓN PASO A PASO**

### **PASO 1: Configurar SonarQube (5 minutos)**

#### 1.1 Acceder a SonarQube
```bash
# Abrir en tu navegador:
http://localhost:9000

# Credenciales iniciales:
Usuario: admin
Contraseña: admin
```

#### 1.2 Cambiar Contraseña
1. SonarQube te pedirá cambiar la contraseña
2. Ingresa una nueva contraseña segura
3. Guarda la contraseña

#### 1.3 Generar Token de Acceso
1. **Click en tu avatar** (esquina superior derecha)
2. **Seleccionar "My Account"**
3. **Ir a pestaña "Security"**
4. **En sección "Tokens":**
   - **Name:** `GitHub Actions Integration`
   - **Type:** `Global Analysis Token`
   - **Expires in:** `No expiration` (o 1 año)
   - **Click "Generate"**
5. **Copiar el token** (formato: `squ_xxxxxxxxxx`)
   
   ⚠️ **IMPORTANTE:** Guarda este token, no se mostrará de nuevo.

#### 1.4 Configurar Quality Gates
```bash
# En tu terminal, ejecutar:
export SONAR_HOST_URL='http://localhost:9000'
export SONAR_TOKEN='squ_tu_token_copiado_aqui'
chmod +x scripts/configure-quality-gate.sh
./scripts/configure-quality-gate.sh
```

**Verificar:** En SonarQube → Quality Gates → Debe aparecer "Android Strict" como default

---

### **PASO 2: Configurar GitHub Repository (3 minutos)**

#### 2.1 Configurar Secrets

1. **Ir a tu repositorio GitHub:**
   ```
   https://github.com/tu-usuario/tu-repositorio
   ```

2. **Navegar a Settings:**
   - Click pestaña **"Settings"**
   - Menú lateral: **"Secrets and variables"** → **"Actions"**

3. **Agregar primer secret:**
   - Click **"New repository secret"**
   - **Name:** `SONAR_HOST_URL`
   - **Secret:** `http://192.168.1.4:9000`
   - Click **"Add secret"**

4. **Agregar segundo secret:**
   - Click **"New repository secret"**
   - **Name:** `SONAR_TOKEN`
   - **Secret:** `squ_tu_token_copiado_aqui`
   - Click **"Add secret"**

#### 2.2 Configurar Branch Protection Rules

**Opción A: Automática (Recomendada)**

1. **Generar GitHub Personal Access Token:**
   - Ir a: https://github.com/settings/tokens
   - Click **"Generate new token (classic)"**
   - **Note:** `SonarQube Branch Protection`
   - **Expiration:** `90 days` (o según prefieras)
   - **Scopes necesarios:**
     - ✅ `repo` (Full control of private repositories)
     - ✅ `admin:repo_hook` (Admin access to repository hooks)
   - Click **"Generate token"**
   - **Copiar el token:** `ghp_xxxxxxxxxxxxxxxxxxxx`

2. **Ejecutar configuración automática:**
   ```bash
   # Configurar variables (reemplaza con tus valores reales):
   export GITHUB_TOKEN="ghp_tu_token_github_copiado"
   export GITHUB_REPO="tu-usuario/tu-repositorio"
   
   # Ejecutar script:
   chmod +x scripts/setup-github-protection.sh
   ./scripts/setup-github-protection.sh
   ```

**Opción B: Manual**

1. **Ir a Branch Protection:**
   - En tu repositorio: **Settings** → **"Branches"**
   - Click **"Add rule"** (o editar regla existente)

2. **Configurar regla para rama principal:**
   - **Branch name pattern:** `main` (o `master`)
   - ✅ **Require status checks to pass before merging**
   - ✅ **Require branches to be up to date before merging**
   - **Status checks required:** (buscar y seleccionar)
     - ✅ `SonarQube Quality Gate`
     - ✅ `SonarQube Analysis`
     - ✅ `Build Android Project`
     - ✅ `Run Tests and Generate Coverage`
   - ✅ **Require pull request reviews before merging**
   - ✅ **Dismiss stale pull request approvals when new commits are pushed**
   - ✅ **Do not allow bypassing the above settings**
   - Click **"Create"** o **"Save changes"**

---

### **PASO 3: Configurar Tu Proyecto Android (5 minutos)**

#### 3.1 Copiar Archivos de Configuración

```bash
# 1. Copiar configuración SonarQube a la raíz de tu proyecto:
cp android-project-setup/sonar-project.properties /ruta/a/tu/proyecto/

# 2. Crear directorio para GitHub Actions:
mkdir -p /ruta/a/tu/proyecto/.github/workflows/

# 3. Copiar workflow:
cp .github/workflows/sonar-analysis.yml /ruta/a/tu/proyecto/.github/workflows/
```

#### 3.2 Personalizar sonar-project.properties

Editar el archivo copiado y cambiar:

```properties
# Cambiar estos valores por los de tu proyecto:
sonar.projectKey=mi_proyecto_android_real
sonar.projectName=Mi Proyecto Android Real
sonar.projectVersion=1.0

# Verificar que las rutas coincidan con tu estructura:
sonar.sources=app/src/main/java,app/src/main/kotlin
sonar.tests=app/src/test/java,app/src/test/kotlin
```

#### 3.3 Configurar Gradle para JaCoCo

Agregar al final de tu `app/build.gradle`:

```gradle
// Agregar plugin JaCoCo
apply plugin: 'jacoco'

android {
    // ... tu configuración existente ...
    
    testOptions {
        unitTests.all {
            useJUnitPlatform()
            finalizedBy jacocoTestReport
        }
    }
    
    buildTypes {
        debug {
            testCoverageEnabled true
        }
        // ... otros buildTypes ...
    }
}

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

tasks.withType(Test) {
    finalizedBy jacocoTestReport
}
```

---

### **PASO 4: Probar la Integración (3 minutos)**

#### 4.1 Commit y Push de Configuración

```bash
# En tu proyecto Android:
cd /ruta/a/tu/proyecto/

# Agregar archivos de configuración:
git add sonar-project.properties
git add .github/workflows/sonar-analysis.yml
git add app/build.gradle

# Commit:
git commit -m "Add SonarQube integration with GitHub Actions"

# Push a rama principal:
git push origin main  # o master
```

#### 4.2 Crear Pull Request de Prueba

```bash
# Crear rama de prueba:
git checkout -b test-sonarqube-integration

# Hacer un cambio menor (agregar comentario, etc.):
echo "// Test SonarQube integration" >> app/src/main/kotlin/MainActivity.kt

# Commit y push:
git add .
git commit -m "Test: SonarQube integration"
git push origin test-sonarqube-integration
```

#### 4.3 Crear Pull Request en GitHub

1. **Ir a tu repositorio en GitHub**
2. **Aparecerá banner:** "Compare & pull request"
3. **Click "Compare & pull request"**
4. **Agregar título:** "Test: SonarQube Integration"
5. **Click "Create pull request"**

#### 4.4 Verificar Pipeline

1. **Ir a pestaña "Actions"** en tu repositorio
2. **Verificar que aparece:** "Android CI/CD with SonarQube"
3. **Click en el workflow** para ver progreso
4. **Observar jobs ejecutándose:**
   - 🔨 Build Android Project
   - 🧪 Run Tests and Generate Coverage
   - 🔍 SonarQube Analysis
   - ⚖️ Quality Gate Validation

---

### **PASO 5: Verificar Bloqueo de Merge (1 minuto)**

#### 5.1 En el Pull Request

1. **Ir al Pull Request creado**
2. **Scroll hacia abajo** hasta la sección "Merge pull request"
3. **Verificar Status Checks:**

   **Si el código cumple estándares:**
   - ✅ All checks have passed
   - ✅ Botón "Merge pull request" habilitado

   **Si el código NO cumple estándares:**
   - ❌ Some checks haven't completed yet
   - ❌ Botón "Merge pull request" deshabilitado
   - ❌ Mensaje: "Merge blocked by failing required status checks"

#### 5.2 Ver Detalles de Status Checks

1. **Click en "Details"** junto a cada status check
2. **Ver logs detallados** del análisis
3. **Ver métricas en SonarQube** (link en los logs)

---

## 🔍 **VERIFICACIÓN COMPLETA**

### Ejecutar Scripts de Validación

```bash
# Verificar configuración completa:
chmod +x scripts/test-deployment.sh
./scripts/test-deployment.sh

# Verificar Branch Protection:
./scripts/setup-github-protection.sh --status

# Probar Quality Gate:
./scripts/test-quality-gate-blocking.sh
```

### Checklist Final

- [ ] ✅ SonarQube accesible en `http://localhost:9000`
- [ ] ✅ Token generado y guardado
- [ ] ✅ Quality Gate "Android Strict" configurado
- [ ] ✅ GitHub Secrets configurados (`SONAR_HOST_URL`, `SONAR_TOKEN`)
- [ ] ✅ Branch Protection Rules activas
- [ ] ✅ Workflow copiado a tu proyecto
- [ ] ✅ `sonar-project.properties` personalizado
- [ ] ✅ JaCoCo configurado en `build.gradle`
- [ ] ✅ Pull Request de prueba creado
- [ ] ✅ Pipeline ejecutándose en GitHub Actions
- [ ] ✅ Status Checks aparecen en PR
- [ ] ✅ Merge bloqueado si Quality Gate falla

---

## 🚨 **TROUBLESHOOTING**

### Error: "actions/upload-artifact@v3 is deprecated"
✅ **SOLUCIONADO** - Workflow actualizado a v4

### Error: SonarQube no accesible
```bash
# Verificar contenedor:
docker ps | grep sonarqube

# Si no está ejecutándose:
docker start $(docker ps -a | grep sonarqube | awk '{print $1}')

# Verificar acceso:
curl -I http://localhost:9000
```

### Error: GitHub Actions falla en análisis
1. **Verificar secrets en GitHub:** Settings → Secrets and variables → Actions
2. **Verificar que `SONAR_HOST_URL` y `SONAR_TOKEN` están configurados**
3. **Verificar que SonarQube es accesible desde internet** (usar IP pública si es necesario)

### Error: Quality Gate no bloquea merge
1. **Verificar Branch Protection Rules:** Settings → Branches
2. **Verificar que incluye "SonarQube Quality Gate" como required status check**
3. **Verificar que "Do not allow bypassing" está habilitado**

---

## 🎉 **¡SISTEMA LISTO!**

Una vez completados todos los pasos:

✅ **Cada commit activa análisis automático**
✅ **GitHub bloquea merges con código de baja calidad**
✅ **Solo código con >80% cobertura y 0 bugs críticos puede hacer merge**
✅ **Desarrolladores reciben feedback inmediato**

### **URLs de Referencia:**
- **SonarQube:** http://localhost:9000
- **Documentación Completa:** [SETUP_GUIDE.md](SETUP_GUIDE.md)
- **Configuración Rápida:** [QUICK_START.md](QUICK_START.md)

---

**🔒 ¡Tu repositorio ahora tiene protección automática de calidad de código!**