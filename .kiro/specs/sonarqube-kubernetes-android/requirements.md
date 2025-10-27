# Documento de Requisitos

## Introducción

Este documento especifica los requisitos para implementar un sistema completo de análisis de calidad de código usando SonarQube desplegado en Kubernetes, con integración CI/CD mediante GitHub Actions que bloquee automáticamente despliegues de proyectos Android que no cumplan con estándares de calidad mínimos, incluyendo una cobertura del 80%.

## Glosario

- **Sistema_SonarQube**: Plataforma de análisis estático de código desplegada en Kubernetes
- **Quality_Gate**: Conjunto de condiciones que debe cumplir el código para aprobar el análisis
- **Pipeline_CI_CD**: Pipeline de integración y despliegue continuo usando GitHub Actions
- **Umbral_Cobertura**: Porcentaje mínimo de cobertura de código requerido (80%)
- **Proyecto_Android**: Proyecto móvil desarrollado en Kotlin/Java usando Gradle
- **Cluster_Kubernetes**: Entorno de orquestación donde se despliega SonarQube
- **Base_Datos_PostgreSQL**: Base de datos persistente para almacenar datos de SonarQube
- **Sonar_Scanner**: Herramienta que ejecuta el análisis del código fuente
- **GitHub_Actions**: Plataforma de CI/CD integrada con GitHub para automatización
- **Branch_Protection_Rules**: Reglas de GitHub que requieren checks exitosos antes de permitir merge
- **Status_Check**: Verificación de estado que debe pasar para permitir merge en GitHub

## Requisitos

### Requisito 1

**Historia de Usuario:** Como Ingeniero DevOps, quiero desplegar SonarQube en Kubernetes con almacenamiento persistente, para que el sistema de análisis de código esté disponible de forma confiable y escalable.

#### Criterios de Aceptación

1. EL Sistema_SonarQube DEBE ser desplegado usando la imagen sonarqube:10.5-community en Kubernetes
2. LA Base_Datos_PostgreSQL DEBE ser desplegada usando la imagen postgres:15 con almacenamiento persistente
3. EL Sistema_SonarQube DEBE persistir datos en el volumen /opt/sonarqube/data
4. LA Base_Datos_PostgreSQL DEBE persistir datos en el volumen /var/lib/postgresql/data
5. EL Sistema_SonarQube DEBE ser accesible a través del puerto 9000 vía NodePort o Ingress

### Requisito 2

**Historia de Usuario:** Como Desarrollador, quiero que SonarQube tenga un Quality Gate configurado con reglas estrictas, para que solo el código de alta calidad pueda ser desplegado a producción.

#### Criterios de Aceptación

1. EL Quality_Gate DEBE requerir un mínimo de 80% de cobertura de código
2. EL Quality_Gate DEBE bloquear el despliegue SI el conteo de bugs críticos es mayor a 0
3. EL Quality_Gate DEBE bloquear el despliegue SI el conteo de vulnerabilidades altas es mayor a 0
4. EL Sistema_SonarQube DEBE analizar código fuente en Kotlin y Java
5. EL Sistema_SonarQube DEBE excluir archivos generados del análisis de cobertura

### Requisito 3

**Historia de Usuario:** Como Desarrollador Android, quiero que mi proyecto sea analizado automáticamente en cada commit, para que pueda identificar problemas de calidad tempranamente en el desarrollo.

#### Criterios de Aceptación

1. CUANDO el código es enviado al repositorio, EL Pipeline_CI_CD DEBE activar el análisis de SonarQube
2. EL Pipeline_CI_CD DEBE compilar el Proyecto_Android usando Gradle
3. EL Pipeline_CI_CD DEBE ejecutar sonar-scanner-cli para el análisis de código
4. EL Pipeline_CI_CD DEBE generar reportes de cobertura JaCoCo
5. EL Pipeline_CI_CD DEBE enviar los resultados del análisis al Sistema_SonarQube

### Requisito 4

**Historia de Usuario:** Como Tech Lead, quiero que el pipeline bloquee automáticamente merges y despliegues cuando el Quality Gate falle, para que ningún código de baja calidad llegue a producción.

#### Criterios de Aceptación

1. CUANDO el análisis del Quality_Gate falla, EL Pipeline_CI_CD DEBE bloquear las pull requests
2. CUANDO el Umbral_Cobertura está por debajo del 80%, EL Pipeline_CI_CD DEBE bloquear el despliegue
3. EL Pipeline_CI_CD DEBE mostrar un mensaje claro de éxito CUANDO el Quality_Gate pasa
4. EL Pipeline_CI_CD DEBE mostrar un mensaje claro de fallo CUANDO el Quality_Gate falla
5. EL Pipeline_CI_CD DEBE proceder solo a la etapa de despliegue CUANDO el Quality_Gate pasa

### Requisito 5

**Historia de Usuario:** Como Ingeniero de Seguridad, quiero que las credenciales y tokens sean manejados de forma segura, para que el acceso a SonarQube esté protegido y no exponga información sensible.

#### Criterios de Aceptación

1. EL Pipeline_CI_CD DEBE usar variables de entorno seguras para SONAR_TOKEN
2. EL Sistema_SonarQube DEBE usar variables de entorno seguras para credenciales de base de datos
3. EL Cluster_Kubernetes DEBE almacenar datos sensibles usando Kubernetes Secrets
4. EL Pipeline_CI_CD NO DEBE exponer credenciales en logs o salida de consola
5. EL Sistema_SonarQube DEBE autenticarse usando autenticación basada en tokens

### Requisito 6

**Historia de Usuario:** Como Ingeniero de Plataforma, quiero que el sistema sea resiliente y se recupere automáticamente de fallos, para que el servicio de análisis de código esté siempre disponible.

#### Criterios de Aceptación

1. EL Sistema_SonarQube DEBE reiniciarse automáticamente CUANDO el contenedor falla
2. LA Base_Datos_PostgreSQL DEBE reiniciarse automáticamente CUANDO el contenedor falla
3. EL Cluster_Kubernetes DEBE mantener volúmenes persistentes CUANDO los pods son recreados
4. EL Sistema_SonarQube DEBE ser desplegado en el namespace sonarqube
5. EL Pipeline_CI_CD DEBE manejar la indisponibilidad temporal de SonarQube de manera elegante

### Requisito 7

**Historia de Usuario:** Como Tech Lead, quiero que GitHub impida físicamente el merge de pull requests hasta que SonarQube confirme que el código cumple con los estándares de calidad, para que sea imposible que código deficiente llegue a las ramas principales.

#### Criterios de Aceptación

1. EL repositorio GitHub DEBE tener Branch_Protection_Rules configuradas que requieran Status_Check exitosos
2. EL Pipeline_CI_CD DEBE reportar su estado como Status_Check a GitHub usando la API de GitHub
3. CUANDO el Quality_Gate falla, EL Status_Check DEBE reportarse como "failed" y GitHub DEBE bloquear el merge
4. CUANDO el Quality_Gate pasa, EL Status_Check DEBE reportarse como "success" y GitHub DEBE permitir el merge
5. EL Status_Check DEBE ser obligatorio y NO DEBE poder ser omitido por administradores sin permisos especiales