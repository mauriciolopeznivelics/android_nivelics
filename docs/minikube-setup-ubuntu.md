# Configuración de Minikube en Ubuntu 24.04 para SonarQube

Este documento describe cómo configurar Minikube en Ubuntu 24.04 para simular un entorno de Kubernetes en la nube (como AWS EKS) y desplegar el sistema SonarQube completo.

## Requisitos del Sistema

### Hardware Mínimo Recomendado
- **CPU**: 2 cores (recomendado 4 cores)
- **RAM**: 4GB (recomendado 8GB)
- **Disco**: 20GB libres (recomendado 50GB)
- **Virtualización**: Habilitada en BIOS/UEFI

### Hardware para Producción
- **CPU**: 4 cores (recomendado 8 cores)
- **RAM**: 8GB (recomendado 16GB)
- **Disco**: 50GB libres (recomendado 100GB)
- **Virtualización**: Habilitada en BIOS/UEFI

### Software Base
- Ubuntu 24.04 LTS
- Conexión a Internet estable
- Permisos de sudo

## Instalación Paso a Paso

### 1. Actualizar el Sistema

```bash
# Actualizar paquetes del sistema
sudo apt update && sudo apt upgrade -y

# Instalar herramientas básicas
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release
```

### 2. Instalar Docker

```bash
# Agregar repositorio oficial de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Reiniciar sesión o ejecutar:
newgrp docker

# Verificar instalación
docker --version
docker run hello-world
```

### 3. Instalar kubectl

```bash
# Descargar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Hacer ejecutable y mover a PATH
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verificar instalación
kubectl version --client
```

### 4. Instalar Minikube

```bash
# Descargar Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Instalar Minikube
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verificar instalación
minikube version
```

### 5. Configurar Minikube para SonarQube

```bash
# Iniciar Minikube con configuración optimizada para SonarQube
minikube start \
  --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --disk-size=50g \
  --kubernetes-version=v1.28.0 \
  --addons=ingress,dashboard,metrics-server

# Verificar estado del cluster
minikube status
kubectl cluster-info
kubectl get nodes
```

### 6. Configurar Almacenamiento Persistente

```bash
# Habilitar addon de almacenamiento
minikube addons enable default-storageclass
minikube addons enable storage-provisioner

# Crear directorios para volúmenes persistentes
minikube ssh 'sudo mkdir -p /data/postgresql /data/sonarqube'
minikube ssh 'sudo chmod 777 /data/postgresql /data/sonarqube'

# Verificar almacenamiento
kubectl get storageclass
```

## Configuración Específica para SonarQube

### 1. Configurar Límites del Sistema

```bash
# Configurar vm.max_map_count para SonarQube (requerido por Elasticsearch)
minikube ssh 'echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf'
minikube ssh 'sudo sysctl -p'

# Verificar configuración
minikube ssh 'sysctl vm.max_map_count'
```

### 2. Configurar Recursos del Cluster

```bash
# Verificar recursos disponibles
kubectl top nodes
kubectl describe nodes

# Si necesitas más recursos, reinicia Minikube con más memoria/CPU
minikube stop
minikube start --cpus=6 --memory=12288 --disk-size=80g
```

### 3. Configurar Acceso Externo

```bash
# Habilitar túnel de Minikube para servicios LoadBalancer
minikube tunnel &

# O usar NodePort (recomendado para desarrollo)
# Los servicios NodePort estarán disponibles en:
# http://$(minikube ip):30900  # SonarQube
```

## Despliegue del Sistema SonarQube

### 1. Clonar el Repositorio

```bash
# Clonar el proyecto
git clone <tu-repositorio>
cd <directorio-proyecto>

# Verificar estructura de archivos
ls -la k8s/
ls -la scripts/
```

### 2. Ejecutar Despliegue Automatizado

```bash
# Hacer ejecutable el script de despliegue
chmod +x deploy.sh

# Ejecutar despliegue completo
./deploy.sh

# Verificar despliegue
kubectl get all -n sonarqube
```

### 3. Configurar SonarQube

```bash
# Esperar a que SonarQube esté completamente iniciado
kubectl wait --for=condition=available --timeout=600s deployment/sonarqube -n sonarqube

# Obtener URL de acceso
SONARQUBE_URL="http://$(minikube ip):$(kubectl get service sonarqube-service -n sonarqube -o jsonpath='{.spec.ports[0].nodePort}')"
echo "SonarQube URL: $SONARQUBE_URL"

# Configurar Quality Gates
chmod +x scripts/configure-quality-gate.sh
export SONAR_HOST_URL=$SONARQUBE_URL
export SONAR_TOKEN="<tu-token-aqui>"  # Generar en SonarQube UI
./scripts/configure-quality-gate.sh
```

## Verificación del Sistema

### 1. Verificar Pods y Servicios

```bash
# Ver estado de todos los recursos
kubectl get all -n sonarqube

# Ver logs de SonarQube
kubectl logs -f deployment/sonarqube -n sonarqube

# Ver logs de PostgreSQL
kubectl logs -f deployment/postgresql -n sonarqube
```

### 2. Verificar Almacenamiento

```bash
# Ver volúmenes persistentes
kubectl get pv
kubectl get pvc -n sonarqube

# Verificar datos en el host
minikube ssh 'ls -la /data/postgresql/'
minikube ssh 'ls -la /data/sonarqube/'
```

### 3. Verificar Conectividad

```bash
# Probar conectividad a SonarQube
curl -I "http://$(minikube ip):$(kubectl get service sonarqube-service -n sonarqube -o jsonpath='{.spec.ports[0].nodePort}')"

# Probar conectividad interna a PostgreSQL
kubectl exec -it deployment/postgresql -n sonarqube -- psql -U sonarqube -d sonarqube -c "SELECT version();"
```

## Comandos Útiles para Desarrollo

### Gestión del Cluster

```bash
# Iniciar Minikube
minikube start

# Parar Minikube
minikube stop

# Eliminar cluster completo
minikube delete

# Ver dashboard de Kubernetes
minikube dashboard

# SSH al nodo de Minikube
minikube ssh
```

### Debugging y Monitoreo

```bash
# Ver eventos del cluster
kubectl get events -n sonarqube --sort-by='.lastTimestamp'

# Describir recursos problemáticos
kubectl describe pod <pod-name> -n sonarqube
kubectl describe pvc <pvc-name> -n sonarqube

# Ver logs en tiempo real
kubectl logs -f deployment/sonarqube -n sonarqube
kubectl logs -f deployment/postgresql -n sonarqube

# Ejecutar comandos dentro de pods
kubectl exec -it deployment/sonarqube -n sonarqube -- /bin/bash
kubectl exec -it deployment/postgresql -n sonarqube -- psql -U sonarqube -d sonarqube
```

### Limpieza y Reinicio

```bash
# Limpiar despliegue completo
./deploy.sh --cleanup

# Reiniciar solo SonarQube
kubectl rollout restart deployment/sonarqube -n sonarqube

# Reiniciar solo PostgreSQL
kubectl rollout restart deployment/postgresql -n sonarqube
```

## Simulación de Entorno AWS

Para simular mejor un entorno de AWS EKS:

### 1. Configurar Ingress (simular ALB)

```bash
# Habilitar ingress controller
minikube addons enable ingress

# Aplicar configuración de ingress
kubectl apply -f k8s/sonarqube-ingress.yaml  # Si existe

# Obtener IP del ingress
kubectl get ingress -n sonarqube
```

### 2. Configurar Monitoreo (simular CloudWatch)

```bash
# Habilitar métricas
minikube addons enable metrics-server

# Ver métricas de recursos
kubectl top nodes
kubectl top pods -n sonarqube
```

### 3. Configurar Backup (simular EBS snapshots)

```bash
# Crear backup manual de datos
kubectl exec deployment/postgresql -n sonarqube -- pg_dump -U sonarqube sonarqube > backup-$(date +%Y%m%d).sql

# Backup de datos de SonarQube
kubectl cp sonarqube/sonarqube-deployment-xxx:/opt/sonarqube/data ./sonarqube-backup-$(date +%Y%m%d)
```

## Troubleshooting Común

### Problema: SonarQube no inicia

```bash
# Verificar vm.max_map_count
minikube ssh 'sysctl vm.max_map_count'

# Si es menor a 524288, configurar:
minikube ssh 'echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf'
minikube ssh 'sudo sysctl -p'

# Reiniciar SonarQube
kubectl rollout restart deployment/sonarqube -n sonarqube
```

### Problema: Falta de recursos

```bash
# Verificar recursos disponibles
kubectl describe nodes

# Aumentar recursos de Minikube
minikube stop
minikube start --cpus=6 --memory=12288
```

### Problema: Volúmenes persistentes

```bash
# Verificar estado de PV/PVC
kubectl get pv
kubectl get pvc -n sonarqube

# Recrear volúmenes si es necesario
kubectl delete pvc postgresql-pvc sonarqube-data-pvc -n sonarqube
kubectl delete pv postgresql-pv sonarqube-data-pv
./deploy.sh
```

## Próximos Pasos

1. **Acceder a SonarQube**: `http://$(minikube ip):30900`
2. **Cambiar contraseña por defecto**: admin/admin
3. **Generar token de acceso** para CI/CD
4. **Configurar Quality Gates** con el script proporcionado
5. **Probar pipeline de GitHub Actions** con el proyecto Android

## Notas Importantes

- **Rendimiento**: Minikube es para desarrollo/testing, no para producción
- **Persistencia**: Los datos se mantienen entre reinicios de pods, pero no del cluster completo
- **Red**: Los servicios NodePort están disponibles en la IP de Minikube
- **Recursos**: Monitorea el uso de CPU/memoria regularmente
- **Backup**: Realiza backups regulares de los datos importantes

Este entorno simula efectivamente un cluster de Kubernetes en la nube y es perfecto para desarrollar y probar el sistema SonarQube antes del despliegue en producción.