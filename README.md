# Sistema SonarQube en Kubernetes para Proyectos Android

Este proyecto implementa un sistema completo de análisis de calidad de código usando SonarQube desplegado en Kubernetes, con integración CI/CD mediante GitHub Actions que **bloquea automáticamente merges** de proyectos Android que no cumplan con estándares de calidad mínimos.

## 🎯 Características Principales

- ✅ **Bloqueo automático de merges** hasta que el código pase SonarQube
- ✅ **Quality Gate estricto** con 80% de cobertura mínima
- ✅ **Cero tolerancia** a bugs críticos y vulnerabilidades altas
- ✅ **Despliegue automatizado** en Kubernetes
- ✅ **Pipeline GitHub Actions** completamente integrado
- ✅ **Análisis específico para Android** (Kotlin/Java)

## 🏗️ Arquitectura del Sistema

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  GitHub Actions  │───▶│   SonarQube     │
│                 │    │                  │    │   (Kubernetes)  │
│ - Android Code  │    │ - Build & Test   │    │                 │
│ - Pull Request  │    │ - SonarQube Scan │    │ - Quality Gate  │
│                 │    │ - Quality Gate   │    │ - PostgreSQL    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         ▲                        │                        │
         │                        ▼                        │
         │              ┌──────────────────┐               │
         └──────────────│ Branch Protection│◀──────────────┘
                        │     Rules        │
                        │                  │
                        │ ❌ Block Merge   │
                        │ ✅ Allow Merge   │
                        └──────────────────┘
```

## 🚀 Inicio Rápido

### 📖 Guías de Configuración

- **⚡ [QUICK_START.md](QUICK_START.md)** - Configuración en 5 minutos
- **📋 [SETUP_GUIDE.md](SETUP_GUIDE.md)** - Guía completa paso a paso
- **🔧 [docs/minikube-setup-ubuntu.md](docs/minikube-setup-ubuntu.md)** - Configuración Minikube

### Prerrequisitos

- **SonarQube ejecutándose** (ver guías de configuración)
- **GitHub repository** con proyecto Android
- **GitHub Personal Access Token**

### Configuración Rápida (5 minutos)

```bash
# 1. SonarQube ya está ejecutándose en: http://localhost:9000
# 2. Seguir la guía rápida:
cat QUICK_START.md

# 3. O seguir la guía completa:
cat SETUP_GUIDE.md
```

### Configuración Completa

Para configuración detallada paso a paso, consulta:
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Guía completa con capturas y explicaciones
- **[QUICK_START.md](QUICK_START.md)** - Configuración rápida en 5 minutos

## 📋 Quality Gate - Estándares de Calidad

El sistema aplica los siguientes estándares **obligatorios**:

### Métricas de Cobertura
- ✅ **Cobertura de código**: ≥ 80%
- ✅ **Nueva cobertura**: ≥ 80%

### Métricas de Calidad
- ✅ **Bugs críticos/blocker**: = 0
- ✅ **Vulnerabilidades altas/críticas**: = 0
- ✅ **Code Smells blocker**: = 0
- ✅ **Líneas duplicadas**: ≤ 3%

### Ratings de Calidad
- ✅ **Maintainability Rating**: ≤ A
- ✅ **Reliability Rating**: ≤ A
- ✅ **Security Rating**: ≤ A

## 🔒 Bloqueo de Merges

### Cómo Funciona

1. **Developer hace push** → GitHub Actions se ejecuta automáticamente
2. **Pipeline ejecuta análisis** → Build, Test, SonarQube Scan
3. **Quality Gate evalúa código** → Verifica todos los criterios
4. **Status Check se actualiza** → GitHub recibe "success" o "failure"
5. **GitHub bloquea/permite merge** → Basado en el resultado

### Status Checks Requeridos

- `SonarQube Quality Gate` - **OBLIGATORIO**
- `SonarQube Analysis` - **OBLIGATORIO**
- `Build Android Project` - **OBLIGATORIO**
- `Run Tests and Generate Coverage` - **OBLIGATORIO**

### Configuración Branch Protection

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "SonarQube Quality Gate",
      "SonarQube Analysis",
      "Build Android Project",
      "Run Tests and Generate Coverage"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  }
}
```

## 🛠️ Configuración del Proyecto Android

### 1. Archivo `sonar-project.properties`

```properties
# Configuración básica
sonar.projectKey=android_app
sonar.projectName=AndroidApp
sonar.sources=app/src/main/java,app/src/main/kotlin
sonar.tests=app/src/test/java,app/src/test/kotlin

# Configuración de cobertura
sonar.coverage.jacoco.xmlReportPaths=app/build/reports/jacoco/testDebugUnitTestCoverage/testDebugUnitTestCoverage.xml

# Exclusiones para archivos generados
sonar.coverage.exclusions=**/R.java,**/R$*.java,**/BuildConfig.*,**/Manifest*.*
```

### 2. Configuración Gradle

```gradle
// En app/build.gradle
android {
    testOptions {
        unitTests.all {
            useJUnitPlatform()
            finalizedBy jacocoTestReport
        }
    }
}

// Plugin JaCoCo para cobertura
apply plugin: 'jacoco'

task jacocoTestReport(type: JacocoReport, dependsOn: ['testDebugUnitTest']) {
    reports {
        xml.enabled = true
        html.enabled = true
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

## 📊 Pipeline GitHub Actions

### Workflow Completo

```yaml
name: Android CI/CD with SonarQube

on:
  push:
    branches: [ master, main, develop ]
  pull_request:
    branches: [ master, main, develop ]

jobs:
  build:          # Compilar proyecto Android
  test:           # Ejecutar pruebas y generar cobertura
  sonar-analysis: # Análisis SonarQube
  quality-gate:   # Validación Quality Gate
  deploy:         # Despliegue (solo si Quality Gate pasa)
```

### Status Checks Automáticos

El pipeline reporta automáticamente el estado a GitHub:

- ⏳ **Pending**: Análisis en progreso
- ✅ **Success**: Quality Gate pasó - merge permitido
- ❌ **Failure**: Quality Gate falló - merge bloqueado

## 🔧 Scripts de Administración

### Despliegue y Configuración

```bash
# Desplegar sistema completo
./deploy.sh

# Ver logs del despliegue
./deploy.sh --logs

# Verificar estado del sistema
./deploy.sh --verify-only

# Limpiar despliegue completo
./deploy.sh --cleanup
```

### Configuración SonarQube

```bash
# Configurar Quality Gates
./scripts/configure-quality-gate.sh

# Verificar configuración
./scripts/health-check.sh

# Validar despliegue
./scripts/validate-deployment.sh
```

### Configuración GitHub

```bash
# Configurar Branch Protection
./scripts/setup-github-protection.sh

# Ver estado actual
./scripts/setup-github-protection.sh --status

# Remover protección (cleanup)
./scripts/setup-github-protection.sh --remove
```

## 🐛 Troubleshooting

### Problemas Comunes

#### SonarQube no inicia

**SonarQube Secrets:**
- `admin`: admin
- `Contraseña`: 4A;i@!1w.$s&

```bash
# Verificar vm.max_map_count
minikube ssh 'sysctl vm.max_map_count'

# Configurar si es necesario
minikube ssh 'echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf'
minikube ssh 'sudo sysctl -p'

# Reiniciar SonarQube
kubectl rollout restart deployment/sonarqube -n sonarqube
```

#### Quality Gate siempre falla

```bash
# Verificar configuración del Quality Gate
curl -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/qualitygates/show?name=Android%20Strict"

# Verificar métricas del proyecto
curl -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/measures/component?component=android_app&metricKeys=coverage,bugs,vulnerabilities"
```

#### Pipeline no reporta Status Checks

```bash
# Verificar GITHUB_TOKEN en secrets
# Verificar permisos del token: repo, admin:repo_hook
# Verificar nombres de Status Checks en Branch Protection Rules
```

### Logs y Debugging

```bash
# Ver logs de SonarQube
kubectl logs -f deployment/sonarqube -n sonarqube

# Ver logs de PostgreSQL
kubectl logs -f deployment/postgresql -n sonarqube

# Ver eventos del cluster
kubectl get events -n sonarqube --sort-by='.lastTimestamp'

# Describir recursos problemáticos
kubectl describe pod <pod-name> -n sonarqube
```

## 📁 Estructura del Proyecto

```
├── k8s/                          # Manifiestos Kubernetes
│   ├── namespace.yaml
│   ├── postgresql-*.yaml
│   ├── sonarqube-*.yaml
│   └── *-service.yaml
├── scripts/                      # Scripts de administración
│   ├── configure-quality-gate.sh
│   ├── setup-github-protection.sh
│   ├── health-check.sh
│   └── validate-deployment.sh
├── .github/workflows/            # GitHub Actions
│   └── sonar-analysis.yml
├── docs/                         # Documentación
│   └── minikube-setup-ubuntu.md
├── deploy.sh                     # Script principal de despliegue
├── setup-sonarqube.sh           # Configuración inicial
└── sonar-project.properties     # Configuración SonarQube
```

## 🔐 Seguridad

### Secrets Requeridos



**GitHub Secrets:**
- `SONAR_HOST_URL`: URL del servidor SonarQube
- `SONAR_TOKEN`: Token de autenticación SonarQube
- `GITHUB_TOKEN`: Token para Status Checks (automático)

**Kubernetes Secrets:**
- `postgresql-secret`: Credenciales de PostgreSQL

### Mejores Prácticas

- ✅ Usar tokens con permisos mínimos necesarios
- ✅ Rotar tokens regularmente
- ✅ No exponer credenciales en logs
- ✅ Usar HTTPS para comunicación externa
- ✅ Configurar RBAC en Kubernetes

## 🚀 Despliegue en Producción

### AWS EKS

```bash
# Configurar kubectl para EKS
aws eks update-kubeconfig --region us-west-2 --name my-cluster

# Usar StorageClass de AWS EBS
# Modificar k8s/*-pv.yaml para usar aws-ebs
# Configurar ALB Ingress Controller para acceso externo
```

### Google GKE

```bash
# Configurar kubectl para GKE
gcloud container clusters get-credentials my-cluster --zone us-central1-a

# Usar StorageClass de GCE Persistent Disk
# Configurar Google Load Balancer
```

### Azure AKS

```bash
# Configurar kubectl para AKS
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster

# Usar StorageClass de Azure Disk
# Configurar Azure Load Balancer
```

## 📈 Monitoreo y Métricas

### Métricas de Calidad

- **Cobertura de código promedio**
- **Número de bugs detectados**
- **Vulnerabilidades encontradas**
- **Tiempo de análisis**
- **Tasa de éxito del Quality Gate**

### Métricas de Pipeline

- **Tiempo total de ejecución**
- **Tasa de éxito de builds**
- **Número de merges bloqueados**
- **Tiempo de feedback a desarrolladores**

## 🤝 Contribución

1. Fork el repositorio
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

**Nota**: Todos los PRs deben pasar el Quality Gate antes del merge.

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver `LICENSE` para más detalles.

## 🆘 Soporte

- **Issues**: [GitHub Issues](https://github.com/tu-usuario/tu-repo/issues)
- **Documentación**: [Wiki del proyecto](https://github.com/tu-usuario/tu-repo/wiki)
- **Discusiones**: [GitHub Discussions](https://github.com/tu-usuario/tu-repo/discussions)

---

**⚡ Sistema que garantiza calidad de código mediante bloqueo automático de merges hasta que el código cumpla con los estándares de SonarQube.**