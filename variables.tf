# Define la región de AWS. Si no la cambias, usará N. Virginia.
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Nombre clave del cliente. 
# ¡IMPORTANTE! Para tus clientes actuales usa: "almey", "soi" o "alfa" (en minúsculas).
variable "cliente_name" {
  type        = string
  description = "Nombre corto del cliente usado para buscar su prefijo en las locals"
}

# Entorno: Usa "Production" o "Staging". El código lo abreviará a "prod" o "stag".
variable "environment" {
  type    = string
  default = "Production"
}

# El tamaño de la máquina de AWS (t3.micro, t3.small, t3.medium, etc.)
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# El límite de dinero mensual para bloquear sorpresas en la factura.
variable "budget_limit" {
  type    = string
  default = "10.0"
}

# El correo donde te llegarán los avisos de CloudWatch y presupuestos.
variable "notif_email" {
  type = string
}
