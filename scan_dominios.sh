#!/bin/bash

# Configuración de Telegram
TELEGRAM_TOKEN="TU_TOKEN_DE_TELEGRAM"  # Reemplaza con tu token
CHAT_ID="TU_ID_DE_CHAT"                 # Reemplaza con tu ID de chat

# Archivo de log para almacenar resultados de escaneo anterior
scan_log="scan_log.txt"
resultados_dir="resultados"  # Carpeta para almacenar resultados
mkdir -p "$resultados_dir"    # Crear carpeta si no existe

# Lista de dominios desde un archivo
dominios=($(cat dominios.txt))

# Función para enviar mensajes a Telegram
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$message"
}

# Comprobar si hay nuevos dominios
check_new_domains() {
    local new_domains=()
    for dominio in "${dominios[@]}"; do
        if ! grep -q "$dominio" "$scan_log"; then
            new_domains+=("$dominio")
            send_telegram_message "Nuevo dominio detectado: $dominio"
        fi
    done
    echo "${new_domains[@]}"
}

# Iniciar escaneo
for dominio in "${dominios[@]}"; do
    send_telegram_message "Iniciando escaneo de: $dominio"
    
    # Escaneo de subdominios con Sublist3r
    send_telegram_message "📄 Escaneando subdominios de $dominio con Sublist3r..."
    sublist3r -d "$dominio" -o "$resultados_dir/${dominio}_sublist3r.txt"
    if [ $? -eq 0 ]; then
        send_telegram_message "✅ Sublist3r completado para $dominio."
    else
        send_telegram_message "⚠️ Error: Sublist3r falló para $dominio."
        continue
    fi

    # Escaneo con Nmap
    nmap -sV -oN "${resultados_dir}/${dominio}_nmap.txt" "$dominio"
    
    # Verificar si Nmap falló
    if [ $? -ne 0 ]; then
        send_telegram_message "Error: La herramienta Nmap falló al escanear el dominio: $dominio"
        continue
    fi
    
    # Guardar en el log
    echo "$dominio" >> "$scan_log"
    
    # Comprobar puertos abiertos
    open_ports=$(grep '/tcp' "${resultados_dir}/${dominio}_nmap.txt" | grep 'open')
    if [ -n "$open_ports" ]; then
        echo "Puertos abiertos detectados para $dominio:"
        echo "$open_ports"
        # Envía un mensaje a Telegram con los puertos abiertos
        send_telegram_message "Puertos abiertos detectados para $dominio:\n$open_ports"
    else
        echo "No se detectaron puertos abiertos para $dominio."
    fi
    
    send_telegram_message "Finalizado escaneo de: $dominio"
done

# Comprobar nuevos dominios al final
new_domains=$(check_new_domains)
if [ -n "$new_domains" ]; then
    send_telegram_message "Nuevos dominios detectados: $new_domains"
else
    send_telegram_message "No se detectaron nuevos dominios."
fi

