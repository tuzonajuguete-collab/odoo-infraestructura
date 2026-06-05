# 🚀 Infraestructura como Código (IaC) para Ecosistema Odoo ERP

Este repositorio contiene la arquitectura de servidores automatizada en **AWS (Amazon Web Services)** utilizando **Terraform** para el despliegue, monitoreo y respaldo de instancias del ERP Odoo. El diseño es completamente modular y está preparado para gestionar múltiples clientes y entornos de forma independiente empleando archivos de variables (`.tfvars`).

---

## 📋 Especificaciones del Entorno Base

Por defecto, la infraestructura estándar para un cliente está diseñada bajo los siguientes parámetros técnicos:
* **Sistema Operativo:** Ubuntu Server 22.04 LTS (Ami nativa de AWS x86_64).
* **Capacidad de Cómputo (CPU y RAM):** Instancia de tipo `t3.micro` (1 vCPU, 1 GB de memoria RAM burstable) ideal para entornos de desarrollo, pruebas o micro-operaciones.
* **Almacenamiento:** Disco de datos SSD tipo `gp3` de **20 GB** con 3000 IOPS y encriptación en reposo activada.
* **Aplicación Destino:** Instancia limpia para Odoo ERP con agente de CloudWatch preconfigurado para monitoreo de logs y rendimiento.

---

## 🗂️ Estructura del Proyecto

El repositorio se compone de los siguientes archivos clave:

* **`main.tf`**: Contiene la lógica central de la infraestructura. Define los recursos que se van a crear en AWS (Servidor EC2, Grupo de Seguridad, IP Elástica, Alertas de CloudWatch, AWS Budgets y Buckets S3).
* **`variables.tf`**: Declara las variables de entrada que el código necesita (región, nombre del cliente, tipo de instancia, límite de presupuesto, etc.) fijando valores seguros por defecto.
* **`jugueteria_almey.tfvars`**: Archivo de asignación de valores específicos para el cliente "Almey". Mantiene separados los datos de negocio del código lógico.
* **`.gitignore`**: Configuración de seguridad para Git. Evita que se suban a GitHub las llaves privadas (`*.pem`), carpetas internas de Terraform o el estado local (`.tfstate`) que podría contener datos sensibles.

---

## 🛠️ Guía de Cambios: ¿Cómo escalar o modificar el Hardware?

Si necesitas cambiar el Sistema Operativo, la CPU, la memoria RAM o el tamaño del disco, **no necesitas modificar el archivo `main.tf`**. Toda la personalización se realiza de la siguiente manera:

### 1. Cambiar la CPU y Memoria RAM
La capacidad del servidor se controla mediante el parámetro `instance_type`. Solo debes cambiar su valor en tu archivo `.tfvars`:
* Para **1 vCPU y 1 GB RAM** (Micro): Usa `t3.micro`.
* Para **2 vCPU y 2 GB RAM** (Pequeño - Recomendado Odoo producción inicial): Usa `t3.small`.
* Para **2 vCPU y 4 GB RAM** (Mediano - Recomendado hasta 15 usuarios activos): Usa `t3.medium`.
* Para **2 vCPU y 8 GB RAM** (Grande): Usa `t3.large`.

### 2. Cambiar el Tamaño del Disco Duro
Si requieres que un cliente de producción tenga más almacenamiento (por ejemplo, **50 GB** o **100 GB** debido a la acumulación de archivos adjuntos y PDFs en Odoo), localiza el bloque `root_block_device` dentro de tu `main.tf` y edita el valor numérico del parámetro:
```hcl
root_block_device {
  volume_size = 50  # <-- Cambia aquí el número de Gigabytes asignados
  volume_type = "gp3"
}

-----------------------------------------------------------------------------------------
3. Cambiar el Sistema Operativo (Ubuntu por otro)
El sistema operativo en AWS se define mediante el ID de la AMI (Amazon Machine Image). Si en lugar de Ubuntu Server 22.04 deseas utilizar otro sistema (como Debian, RedHat o Amazon Linux):

Busca el ID de la AMI correspondiente a la región (ej: us-east-1) desde la consola de AWS.

Modifica el parámetro ami dentro del recurso aws_instance en tu main.tf:

Terraform


resource "aws_instance" "odoo_server" {
  ami = "ami-xxxxxxxxxxxxxxxxx" # <-- Reemplaza con el ID del nuevo Sistema Operativo
}
➕ ¿Cómo agregar un nuevo Cliente o Infraestructura?
Para añadir una nueva infraestructura para otra juguetería (por ejemplo, "Juguetería Juguetón") o cualquier otro rubro de cliente, sigue estos 3 simples pasos:

Paso A: Registrar el prefijo del cliente en main.tf
Abre main.tf, ve al bloque locals {} y añade la abreviatura que usará el cliente en su arquitectura para mantener la nomenclatura limpia:

Terraform


client_prefix = {
  "almey"    : "jug-almey"
  "soi"      : "jug-soi"
  "alfa"     : "const-alfa"
  "jugueton" : "jug-jugueton" # <-- Agrega tu nuevo cliente aquí
}
Paso B: Crear su archivo de variables personalizado
Crea un nuevo archivo en la raíz llamado jugueteria_jugueton.tfvars y define sus propios parámetros de negocio y límites de dinero:

Terraform


cliente_name  = "jugueton"
environment   = "Production"
instance_type = "t3.small"        # <-- Asignado con 2GB de RAM para producción
budget_limit  = "30.0"            # <-- Alerta de AWS Budgets a los $30 USD mensuales
notif_email   = "tuzonajuguete@gmail.com"
Paso C: Desplegar la nueva infraestructura
Ejecuta los comandos de Terraform apuntando específicamente al nuevo archivo de variables que acabas de crear:

Bash


terraform plan -var-file="jugueteria_jugueton.tfvars"
terraform apply -var-file="jugueteria_jugueton.tfvars"
AWS construirá discos, IPs, servidores y alarmas completamente aislados y etiquetados de forma automática bajo el nombre del nuevo cliente.