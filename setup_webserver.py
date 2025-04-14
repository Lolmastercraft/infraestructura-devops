#!/usr/bin/env python3
import subprocess
import sys

# 1. Actualizar paquetes e instalar Apache (httpd)
subprocess.run(["sudo", "yum", "update", "-y"])
subprocess.run(["sudo", "yum", "install", "-y", "httpd"])

# 2. Determinar el identificador único del servidor para el HTML
# Si se pasa un argumento al script, úsalo como número de servidor
server_id = ""
if len(sys.argv) > 1:
    server_id = sys.argv[1]

# Contenido HTML único para este servidor
titulo = f"Servidor Web {server_id}" if server_id else "Servidor Web"
html_content = f"""<html>
<head><title>{titulo}</title></head>
<body>
  <h1>{titulo}</h1>
  <p>Este servidor web est\u00e1 en funcionamiento.</p>
</body>
</html>"""

# 3. Escribir el archivo HTML en /var/www/html/index.html
with open("index.html", "w") as f:
    f.write(html_content)
# Mover el archivo al directorio web de Apache con privilegios
subprocess.run(["sudo", "mv", "index.html", "/var/www/html/index.html"])

# 4. Iniciar y habilitar el servicio Apache
subprocess.run(["sudo", "systemctl", "start", "httpd"])
subprocess.run(["sudo", "systemctl", "enable", "httpd"])

