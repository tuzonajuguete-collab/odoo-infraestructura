# =========================================================================
# CONFIGURACIÓN DE VARIABLES PARA EL CLIENTE: JUGUETERÍA ALMEY
# =========================================================================

# 1. IDENTIFICACIÓN DEL CLIENTE
# Opciones válidas configuradas en tus locals: "almey", "soi" o "alfa".
# Al poner "almey", tu main.tf le asignará el prefijo normado "jug-almey".
cliente_name = "almey"

# 2. ENTORNO DE TRABAJO
# Opciones: "Production" (se abrevia a "prod") o "Staging" (se abrevia a "stag").
# Define si es el servidor en vivo para los clientes o el de pruebas internas.
environment = "Production"

# 3. POTENCIA Y CAPACIDAD DEL SERVIDOR (CPU y RAM)
# Cambia este valor aquí cuando el cliente crezca o requiera más velocidad:
# - "t3.micro"  : 1 vCPU, 1 GB RAM -> Económico, ideal para pruebas o flujos muy bajos.
# - "t3.small"  : 2 vCPU, 2 GB RAM -> Intermedio.
# - "t3.medium" : 2 vCPU, 4 GB RAM -> MÍNIMO RECOMENDADO para Odoo en producción estable.
# - "t3.large"  : 2 vCPU, 8 GB RAM -> Recomendado para empresas con más de 15 usuarios activos.
instance_type = "t3.micro"

# 4. CONTROL DE COSTOS (Presupuesto Mensual en USD)
# El límite de dinero en dólares. Si los recursos de este cliente gastan más del 80% 
# de este valor en el mes, AWS te enviará un correo de advertencia inmediatamente.
budget_limit = "10.0"

# 5. CORREO ELECTRÓNICO PARA ALERTAS CRÍTICAS
# Aquí centralizas las alertas de este cliente. Te llegarán avisos si:
# - La CPU supera el 80% por más de 15 minutos.
# - El disco duro se llena a más del 85% de su capacidad.
# - La memoria RAM se satura por encima del 90%.
# - El presupuesto mensual configurado arriba supera el 80% de consumo.
notif_email = "tuzonajuguete@gmail.com"

