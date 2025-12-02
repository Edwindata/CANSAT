                                                                    # CANSAT
Sistema de telemetría avanzado para CanSat basado en ESP32-C6 y Processing con visualización 3D, trazo de ruta GPS en tiempo real y comunicación de largo alcance vía NRF24.

                                        🛰️ CanSat Telemetry System: ESP32-C6 & Processing Ground Station
Un sistema avanzado de telemetría para satélites pequeños (CanSat) basado en arquitectura Maestro-Esclavo vía radiofrecuencia de largo alcance.

El proyecto consta de un Satélite (Flight Computer) basado en el moderno ESP32-C6 (RISC-V) y una Estación Terrena basada en ESP32-WROOM, visualizando datos en tiempo real a través de una interfaz gráfica potente desarrollada en Processing.


                                                       🚀 Características Principales
                                                           📡 Comunicación y Radio
                                                                   
Enlace Inalámbrico: Transmisión robusta vía NRF24L01+PA+LNA.
Modo Competencia: Configurado en el Canal 108 (2.508 GHz) para evitar interferencias de Wi-Fi.
Integridad de Datos: Paquetes comprimidos (__attribute__((packed))) con CRC de 16-bits y sistema de reintentos automáticos.
Alcance: Velocidad optimizada a 250KBPS para máxima penetración y distancia.

                                                             🛰️ Satélite (Flight Unit)
                                                                  
Cerebro: ESP32-C6 (RISC-V Single Core) con multitarea cooperativa optimizada.
Fusión de Sensores: Algoritmo que combina Barómetro (BMP180) y GPS para una altimetría precisa.
Monitoreo de Energía: Lectura de voltaje de batería LiPo en tiempo real con calibración por software.
Autodiagnóstico: Chequeo de salud de sensores (MPU, BMP, DHT, GPS) y reporte de estado a tierra.

Indicadores Visuales:

LED Integrado: Latido de comunicación (Heartbeat).
Aro NeoPixel: Semáforo de estado (GPS Fix, Batería, Errores).

                                                    🌍 Estación Terrena (Ground Station)
                                                              
Interfaz Física: Pantalla OLED 128x32 con 4 páginas de datos navegables mediante botón físico.
Pasarela de Datos: Inyección de telemetría por USB a 921600 baudios para latencia cero.
Diagnóstico Local: Monitoreo de calidad de señal RF (%) y uso de RAM.

                                                        💻 Interfaz de Control (Processing)

Modelo 3D: Visualización de orientación en tiempo real (Pitch/Roll/Yaw) sin gimbal lock. 

Mapa GPS en Vivo: Integración con Google Maps Static API. 

Tracking de Ruta: Dibuja el recorrido exacto del satélite sobre el mapa. 

Herramienta de Medición: "Cinta métrica" GPS para medir distancias recorridas en tiempo real. 

Gráficas en Vivo: Historial de 5 minutos de Temperatura, Humedad y Presión. 

HUD Profesional: Instrumentación estilo aeronáutico. 


                                                            🛠️ Hardware Requerido
                                                              Satélite (Transmisor)

Microcontrolador: ESP32-C6-WROOM-1 (DevKit)

IMU: MPU6050 (Giroscopio + Acelerómetro)

Barómetro: BMP180 (Presión y Altura)

GPS: GY-GPS6MV2 (NEO-6M)

Sensor Clima: DHT11 (Temperatura y Humedad)

Radio: NRF24L01+PA+LNA (Con Antena)

Batería: LiPo 3.7V / 18650

Extras: "Capacitor 100µF (Radio), Resistencias 100k (Divisor Voltaje)"


                                                               Base Terrena (Receptor)
                                                                
Microcontrolador: ESP32-WROOM-32 (DevKit V1)

Radio: NRF24L01+PA+LNA

Display: OLED 0.91" I2C (128x32) Controlador SSD1306

Input: Push Button (Normalmente Abierto)

                                                      🔌 Diagrama de Conexiones (Pinout)
                                                          🛰️ Satélite (ESP32-C6)
                                                          
Nota: Distribución dividida para evitar cruce de cables.

Lado Izquierdo (Sensores):

DHT11 Data: GPIO 3

GPS RX: GPIO 4

GPS TX: GPIO 5

I2C SDA: GPIO 6

I2C SCL: GPIO 7

Batería (Divisor): GPIO 2 (ADC)

Lado Derecho (Radio NRF24):

CE: GPIO 18

CSN: GPIO 19

SCK: GPIO 20

MISO: GPIO 21

MOSI: GPIO 22

(Recordatorio: Soldar capacitor en VCC/GND del NRF24)

                                                        🌍 Base Terrena (ESP32-WROOM)

Radio CE: GPIO 4

Radio CSN: GPIO 5

Radio SCK: GPIO 18

Radio MISO: GPIO 19

Radio MOSI: GPIO 23

OLED SDA: GPIO 21

OLED SCL: GPIO 22

Botón: GPIO 15 (A GND)

                                                      💾 Instalación y Software
                                                        Firmware (Arduino IDE)
                                                        
Librerías:

RF24 by TMRh20

Adafruit MPU6050

Adafruit BMP085 Library

DHT sensor library

TinyGPSPlus

Adafruit SSD1306 & Adafruit GFX

Adafruit NeoPixel

                                                  Configuración ESP32-C6 en IDE 🛰️

Board: ESP32C6 Dev Module

USB CDC On Boot: Enabled 

                                                      Interfaz (Processing 4) 
                                                      
API Key: Debes obtener una API Key de Google Maps Platform y habilitar "Maps Static API".

Pégala en la línea String apiKey = "TU_API_KEY"; del código .ide.

                                                      🕹️ Manual de Operación
                                                      
Secuencia de Encendido:

Conecta la Base Terrena a la PC vía USB.

Abre Processing y ejecuta el Sketch.

Conecta la batería del Satélite.

⚠️ IMPORTANTE: Deja el satélite totalmente quieto sobre una superficie plana durante los primeros 5 segundos.

Razón: El sistema está calibrando el giroscopio y definiendo la "Altura Cero" barométrica.

Uso de la Base (OLED)
Presiona el botón físico para ciclar entre pantallas:

GPS: Muestra Latitud, Longitud, Satélites y Precisión.

SENSOR: Altura relativa, Temperatura, Humedad, Presión.

BASE STAT: Calidad de señal RF (%) y carga de CPU/RAM de la base.

SAT HEALTH: Voltaje de batería del satélite y estado de cada sensor (M=MPU, B=BMP, D=DHT, G=GPS).

Uso de la Interfaz (Processing)
Botón "3D / MAPA / GRÁFICAS": Cambia entre la vista del modelo, el mapa GPS y las gráficas históricas.

Botón "MEDIR RUTA": (En vista Mapa)

Clic 1 (Naranja): Empieza a grabar recorrido y medir distancia.

Clic 2 (Verde): Termina ruta y descarga mapa con el trayecto dibujado.

Clic 3: Reinicia.

Tecla 'R': Fuerza la descarga manual del mapa si internet falla.

                                                      ⚠️ Solución de Problemas Comunes
                                                      
  Problema,	                                             Causa Probable,	                                        Solución
 
"CHK: ERR" en Base,                                Fallo de sensor en el satélite,	                Revisa cables I2C (SDA/SCL) o conexión DHT.

Processing pantalla negra,	                        Error de API Key o Puerto,                     	Revisa tu API Key de Google y cierra el Monitor Serie de Arduino.

Batería marca 0V,                                 	Divisor de voltaje desconectado,	                Revisa conexión al GPIO 2 y GND.

Radio no conecta,                                      	Falta de energía,                        	Suelda el capacitor en el NRF24

Altura marca 80m en el suelo,	                        Calibración fallida,	                        Reinicia el satélite y no lo muevas mientras enciende.

                                                                📄 Licencia
                                                                
Este proyecto es de código abierto. Siéntete libre de usarlo, modificarlo y mejorarlo para tus competencias de CanSat o proyectos universitarios.

Desarrollado por: Edwin's Lab.
