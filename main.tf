# =========================================================================
# LÓGICA CORE: CONFIGURACIÓN DE PROVEEDORES
# =========================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =========================================================================
# 1. ZONA DE LOCALES: NORMALIZACIÓN Y PREFIJOS DINÁMICOS
# =========================================================================
locals {
  # Convierte "Production" en "prod" y "Staging" en "stag" automáticamente para los nombres de AWS.
  env_short = var.environment == "Production" ? "prod" : "stag"

  # 💡 ¿QUÉ CAMBIA AQUÍ SI AGREGAS UN NUEVO CLIENTE?
  # -----------------------------------------------------------------------
  # Si das de alta un cliente en tu archivo .tfvars (ej: cliente_name = "jugueton"), 
  # vienes aquí y mapeas su clave interna para mantener la nomenclatura limpia:
  #   "jugueton" : "jug-jugueton"
  # -----------------------------------------------------------------------
  client_prefix = {
    "almey" : "jug-almey"
    "soi"   : "jug-soi"
    "alfa"  : "const-alfa"
  }

  # Busca el prefijo estandarizado. Si no existe en la lista, usa "cli-nombre" de respaldo.
  pfx = lookup(local.client_prefix, lower(var.cliente_name), "cli-${lower(var.cliente_name)}")

  # ETIQUETADO DE COSTOS: Esto es lo que lee tu alerta de AWS Budgets.
  tags_compartidas = {
    Client      = upper(var.cliente_name)
    Environment = upper(local.env_short)
    Project     = "Odoo-Ecosystem"
    ManagedBy   = "Terraform"
  }

  # NOMENCLATURA AUTOMÁTICA DE RECURSOS (No tocar, se genera sola basados en tus variables)
  nombre_servidor         = "cli-${local.pfx}-odoo-${local.env_short}"
  nombre_ip               = "eip-${local.pfx}-${local.env_short}"
  nombre_disco            = "vol-${local.pfx}-${local.env_short}-data"
  nombre_bucket           = "backups-odoo-${local.pfx}-${local.env_short}-secure-2026"
  nombre_sg               = "odoo-sg-${local.pfx}-${local.env_short}"
  nombre_log_group_syslog = "Odoo-Ecosystem-${local.pfx}-${local.env_short}-Syslogs"
  nombre_log_group_app    = "Odoo-Ecosystem-${local.pfx}-${local.env_short}-Application-Logs"
}

# =========================================================================
# 2. LLAVES SSH AUTOMÁTICAS (.PEM)
# =========================================================================
resource "tls_private_key" "key_generada" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "key_pair_aws" {
  key_name   = "key-${local.pfx}-${local.env_short}"
  public_key = tls_private_key.key_generada.public_key_openssh
  tags       = local.tags_compartidas
}

resource "local_file" "guardar_llave_pem" {
  content  = tls_private_key.key_generada.private_key_pem
  filename = "${path.module}/${local.nombre_servidor}.pem"
}

# =========================================================================
# 3. SEGURIDAD: FIREWALL DE RED (SECURITY GROUP)
# =========================================================================
resource "aws_security_group" "odoo_sg" {
  name        = local.nombre_sg
  description = "Permitir trafico SSH, HTTP y HTTPS para Odoo"
  tags        = merge(local.tags_compartidas, { Name = local.nombre_sg })

  # 💡 TESTING VS PRODUCCIÓN EN PUERTOS:
  # -----------------------------------------------------------------------
  # - En instancias de TESTING: Mantener ["0.0.0.0/0"] es cómodo para ingresar rápido.
  # - En instancias de PRODUCCIÓN: Se recomienda restringir el puerto 22 (SSH) 
  #   reemplazando "0.0.0.0/0" por la IP pública fija de tu oficina/casa (ej: ["181.41.22.5/32"])
  #   para mitigar ataques de fuerza bruta al servidor.
  # -----------------------------------------------------------------------
  ingress {
    description = "Acceso SSH desde el exterior"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "Trafico HTTP web"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Trafico HTTPS seguro web"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =========================================================================
# 4. ROLES DE ACCESO (IAM PARA MONITOREO CLOUDWATCH)
# =========================================================================
resource "aws_iam_role" "ec2_monitor_role" {
  name = "Rol-Monitoreo-EC2-${local.pfx}-${local.env_short}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = local.tags_compartidas
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attach" {
  role       = aws_iam_role.ec2_monitor_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "Perfil-Monitoreo-EC2-${local.pfx}-${local.env_short}"
  role = aws_iam_role.ec2_monitor_role.name
}

# =========================================================================
# 5. CÓMPUTO Y HARDWARE (EC2, IP ELÁSTICA Y ALMACENAMIENTO)
# =========================================================================
resource "aws_eip" "odoo_static_ip" {
  domain = "vpc"
  tags = merge(local.tags_compartidas, { Name = local.nombre_ip })
}

resource "aws_instance" "odoo_server" {
  ami                    = "ami-0c7217cdde317cfec" 
  instance_type          = var.instance_type       
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = aws_key_pair.key_pair_aws.key_name
  vpc_security_group_ids = [aws_security_group.odoo_sg.id]

  # 💡 CRÉDITOS BURSTABLE (MÁQUINAS T3):
  # -----------------------------------------------------------------------
  # - En TESTING: "standard" es perfecto porque el uso es esporádico.
  # - En PRODUCCIÓN: Se sugiere evaluar cambiarlo a "unlimited" si el Odoo del cliente
  #   procesa mucha facturación o reportes pesados. Evita que la máquina se ralentice 
  #   cuando se agotan los créditos de CPU base.
  # -----------------------------------------------------------------------
  credit_specification {
    cpu_credits = "standard" 
  }

  # 💡 POLÍTICA DE RESGUARDO EN DISCOS:
  # -----------------------------------------------------------------------
  # - volume_size: Odoo Testing = 20 GB | Odoo Producción = 40GB a 100GB (Por almacenamiento de PDFs/Imágenes).
  # - delete_on_termination: En TESTING se usa 'true' para limpiar todo al destruir.
  #   En PRODUCCIÓN cambia a 'false' como seguro de vida: si destruyes la EC2 por error, 
  #   el disco rígido gp3 no se borra y preservas la base de datos intacta.
  # -----------------------------------------------------------------------
  root_block_device {
    volume_size           = 20     
    volume_type           = "gp3"  
    iops                  = 3000   
    throughput            = 125    
    encrypted             = true   
    delete_on_termination = false  

    tags = merge(local.tags_compartidas, { Name = local.nombre_disco })
  }

  # USER DATA: Proceso automatizado dentro del Linux.
  # Corregido con el esquema plano para evitar fallos de inicialización del agente de AWS.
  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive

              while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
                echo "Esperando a que termine otra instalación en segundo plano..."
                sleep 5
              done

              apt-get update -y
              apt-get install wget curl -y
              wget https://amazoncloudwatch-agent-us-east-1.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
              dpkg -i /tmp/amazon-cloudwatch-agent.deb

              mkdir -p /var/log/odoo
              touch /var/log/odoo/odoo-server.log
              mkdir -p /opt/aws/amazon-cloudwatch-agent/bin/

              # Configuración limpia del agente de CloudWatch (Métricas + Logs estructurados planos)
              cat << CONFIGEOF > /opt/aws/amazon-cloudwatch-agent/bin/config.json
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "run_as_user": "root"
                },
                "metrics": {
                  "metrics_collected": {
                    "disk": {
                      "measurement": ["disk_used_percent"],
                      "metrics_collection_interval": 60,
                      "resources": ["/"]
                    },
                    "mem": {
                      "measurement": ["mem_used_percent"],
                      "metrics_collection_interval": 60
                    }
                  }
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/syslog",
                          "log_group_name": "${local.nombre_log_group_syslog}",
                          "log_stream_name": "{hostname}-syslog",
                          "retention_in_days": 7
                        },
                        {
                          "file_path": "/var/log/odoo/*.log",
                          "log_group_name": "${local.nombre_log_group_app}",
                          "log_stream_name": "{hostname}-odoo",
                          "retention_in_days": 7
                        }
                      ]
                    }
                  }
                }
              }
              CONFIGEOF

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
              
              systemctl enable amazon-cloudwatch-agent
              systemctl restart amazon-cloudwatch-agent
              EOF

  tags = merge(local.tags_compartidas, { Name = local.nombre_servidor })
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.odoo_server.id
  allocation_id = aws_eip.odoo_static_ip.id
}

# =========================================================================
# 6. CAPA DE ALMACENAMIENTO DE BACKUPS (S3 BUCKET)
# =========================================================================
resource "aws_s3_bucket" "backup_bucket" {
  bucket        = local.nombre_bucket
  force_destroy = false 

  tags = merge(local.tags_compartidas, { Name = "s3-bucket-${var.cliente_name}" })
}

resource "aws_iam_user" "backup_user" {
  name = "usuario-script-backup-${var.cliente_name}"
  tags = local.tags_compartidas
}

resource "aws_iam_access_key" "user_keys" {
  user = aws_iam_user.backup_user.name
}

resource "aws_iam_user_policy" "backup_policy" {
  name = "Permiso-Subir-Backups-${var.cliente_name}"
  user = aws_iam_user.backup_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.backup_bucket.arn}",
          "${aws_s3_bucket.backup_bucket.arn}/*"
        ]
      }
    ]
  })
}

# =========================================================================
# 7. CAPA DE ALERTAS, ADVERTENCIAS Y LOGS (CLOUDWATCH ALARMS)
# =========================================================================
resource "aws_sns_topic" "alerts_topic" {
  name = "Alerta-Infraestructura-${var.cliente_name}"
  tags = local.tags_compartidas
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alerts_topic.arn
  protocol  = "email"
  endpoint  = var.notif_email
}

resource "aws_cloudwatch_log_group" "odoo_syslogs" {
  name              = local.nombre_log_group_syslog
  retention_in_days = 7
  tags              = local.tags_compartidas
}

resource "aws_cloudwatch_log_group" "odoo_app_logs" {
  name              = local.nombre_log_group_app
  retention_in_days = 7
  tags              = local.tags_compartidas
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "Alarma-CPU-Excedida-${var.cliente_name}-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Vigila si los workers de Odoo están saturando la CPU"
  alarm_actions       = [aws_sns_topic.alerts_topic.arn]

  dimensions = { InstanceId = aws_instance.odoo_server.id }
  tags = local.tags_compartidas
}

# 💡 AJUSTE DE UMBRALES DE CRITICIDAD (MÉTRICAS DEL AGENTE):
# -----------------------------------------------------------------------
# Los porcentajes límetes (threshold) definen cuándo se dispara el correo de alerta:
# - En TESTING: Puedes dejar límites altos (ej. RAM al 95%, Disco al 90%) ya que el colapso no es grave.
# - En PRODUCCIÓN: Se aconseja un umbral predictivo (ej. RAM al 85%, Disco al 80%) para darte
#   un colchón de tiempo operativo antes de que el disco se llene por completo e interrumpa el servicio.
# -----------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "disco_alarm" {
  alarm_name          = "Alarma-Disco-Casi-Lleno-${var.cliente_name}-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "85" # <-- Sugerido bajar a 80 en Producción
  alarm_description   = "Alerta si el almacenamiento EBS se está quedando sin espacio libre"
  alarm_actions       = [aws_sns_topic.alerts_topic.arn]

  dimensions = {
    InstanceId = aws_instance.odoo_server.id
    path       = "/"
  }
  tags = local.tags_compartidas
}

resource "aws_cloudwatch_metric_alarm" "ram_alarm" {
  alarm_name          = "Alarma-RAM-Saturada-${var.cliente_name}-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "90" # <-- Sugerido bajar a 85 en Producción
  alarm_description   = "Evita cuelgues críticos si PostgreSQL o los workers agotan la memoria"
  alarm_actions       = [aws_sns_topic.alerts_topic.arn]

  dimensions = { InstanceId = aws_instance.odoo_server.id }
  tags = local.tags_compartidas
}

resource "aws_cloudwatch_metric_alarm" "instance_health_alarm" {
  alarm_name          = "Alarma-Servidor-Apagado-o-Inalcanzable-${var.cliente_name}-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "Dispara una alerta inmediata si el hardware físico falla o la máquina se apaga"
  alarm_actions       = [aws_sns_topic.alerts_topic.arn]

  dimensions = { InstanceId = aws_instance.odoo_server.id }
  tags = local.tags_compartidas
}

# =========================================================================
# 8. CAPA DE PRESUPUESTOS (AWS BUDGETS)
# =========================================================================
resource "aws_budgets_budget" "client_budget" {
  name              = "Presupuesto-${var.cliente_name}-${var.environment}"
  budget_type       = "COST"
  limit_amount      = var.budget_limit
  limit_unit        = "USD"
  time_period_start = "2026-01-01_00:00"
  time_unit         = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["Client$${upper(var.cliente_name)}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notif_email]
  }
}

# =========================================================================
# DATA DE SALIDA (OUTPUTS)
# =========================================================================
output "ip_publica_fija" {
  value = aws_eip.odoo_static_ip.public_ip
}

output "script_aws_access_key" {
  value = aws_iam_access_key.user_keys.id
}

output "script_aws_secret_key" {
  value     = aws_iam_access_key.user_keys.secret
  sensitive = true
}