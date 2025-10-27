# ⚡ Configuración Rápida - SonarQube + GitHub Actions

## 🎯 Resumen

Sistema que **bloquea automáticamente merges** hasta que el código pase SonarQube con 80% cobertura y cero bugs críticos.

## 🚀 Configuración en 5 Minutos

### 1️⃣ SonarQube (2 minutos)

```bash
# 1. Acceder a SonarQube
# URL: http://localhost:9000
# Login: admin/admin (cambiar contraseña)

# 2. Generar token
# My Account → Security → Tokens → Generate
# Name: "GitHub Actions Integration"
# Copiar: squ_xxxxxxxxxx

# 3. Configurar Quality Gates automáticamente
export SONAR_HOST_URL='http://localhost:9000'
export SONAR_TOKEN='squ_tu_token_aqui'
./scripts/configure-quality-gate.sh
```

### 2️⃣ GitHub Secrets (1 minuto)

```bash
# Ir a: GitHub.com → Tu Repo → Settings → Secrets and variables → Actions

# Agregar secrets:
SONAR_HOST_URL = http://192.168.34.214:9000
SONAR_TOKEN = squ_tu_token_copiado
```

### 3️⃣ Branch Protection (1 minuto)

```bash
# Opción A: Automática
export GITHUB_TOKEN="ghp_tu_token_github"
export GITHUB_REPO="tu-usuario/tu-repo"
./scripts/setup-github-protection.sh

# Opción B: Manual
# GitHub → Settings → Branches → Add rule
# Require status checks: "SonarQube Quality Gate"
```

### 4️⃣ Proyecto Android (1 minuto)

```bash
# 1. Copiar archivos de configuración
cp sonar-project.properties tu-proyecto/
cp .github/workflows/sonar-analysis.yml tu-proyecto/.github/workflows/

# 2. Agregar JaCoCo a app/build.gradle
apply plugin: 'jacoco'
# (Ver SETUP_GUIDE.md para configuración completa)
```

## ✅ Verificación Rápida

```bash
# 1. Crear PR de prueba
git checkout -b test-integration
git commit -m "Test SonarQube" --allow-empty
git push origin test-integration

# 2. Verificar en GitHub:
# - Actions tab: Pipeline ejecutándose
# - PR: Status checks aparecen
# - Merge: Bloqueado si Quality Gate falla
```

## 🎉 ¡Listo!

- ✅ **Merges bloqueados** hasta pasar SonarQube
- ✅ **80% cobertura mínima** requerida
- ✅ **Cero bugs críticos** permitidos
- ✅ **Feedback automático** en PRs

## 📋 URLs Importantes

- **SonarQube Local:** http://localhost:9000
- **SonarQube Red:** http://192.168.34.214:9000
- **Documentación Completa:** [SETUP_GUIDE.md](SETUP_GUIDE.md)
- **Troubleshooting:** [README.md](README.md)

---

**⚡ En 5 minutos tienes un sistema que garantiza calidad de código automáticamente.**