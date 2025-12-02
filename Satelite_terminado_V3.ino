

#include <SPI.h>
#include <RF24.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>
#include <Adafruit_BMP085.h>
#include <DHT.h>
#include <TinyGPS++.h>
#include <Adafruit_NeoPixel.h>

#define PIN_ONBOARD 8  
#define PIN_RING    1  
#define NUM_PIXELS  4  
Adafruit_NeoPixel ring(NUM_PIXELS, PIN_RING, NEO_GRB + NEO_KHZ800);

#define PIN_CE    18
#define PIN_CSN   19
#define PIN_SCK   20
#define PIN_MISO  21
#define PIN_MOSI  22
#define SDA_PIN 6
#define SCL_PIN 7
#define RX_GPS_PIN 5 
#define TX_GPS_PIN 4 
#define DHTPIN 3      
#define DHTTYPE DHT11 
#define BAT_PIN 2    

float batteryCalibration = 1.98; 

SPIClass spiRadio(FSPI); 
RF24 radio(PIN_CE, PIN_CSN); 
const byte address[6] = "SAT01";

Adafruit_MPU6050 mpu; Adafruit_BMP085 bmp; DHT dht(DHTPIN, DHTTYPE);
TinyGPSPlus gps; HardwareSerial GPS_Serial(1); 


struct __attribute__((packed)) PacketA { 
  byte id = 1; 
  float r, p, y, ax, ay, az, gx; 
};

struct __attribute__((packed)) PacketB { 
  byte id = 2; 
  float bat; 
  float gy, gz, pres, alt, temp, hum; 
  byte ram; 
  byte status; 
};

struct __attribute__((packed)) PacketC { 
  byte id = 3; 
  float lat, lon; 
  int sats; 
  float hdop; 
};

PacketA pkgA; PacketB pkgB; PacketC pkgC;

float lat_s=0, lon_s=0; int sats_s=0; float hdop_s=10.0; bool gpsFix=false; 
float tDHT_s=0, hDHT_s=0;
float gx_off=-7.55, gy_off=0.22, gz_off=-0.83; 
float pitch=0, roll=0, yaw=0;
unsigned long prevTime; float altBase=0, altFus=0, altPrev=0;
bool mpuOK = false, bmpOK = false;
unsigned long lastAckTime = 0; 
unsigned long lastDHTTime = 0;
unsigned long lastPixelUpdate = 0;
float currentBat = 0; byte currentStatus = 0;

float readBattery() {
  long suma = 0;
  for(int i=0; i<20; i++) { suma += analogReadMilliVolts(BAT_PIN); delay(2); }
  float voltajePin = (suma / 20.0) / 1000.0; 
  return voltajePin * batteryCalibration;
}

byte getRamUsage() { uint32_t free = ESP.getFreeHeap(); uint32_t total = ESP.getHeapSize(); return (byte)(100 - ((free * 100) / total)); }

void updateLights() {
  if (millis() - lastAckTime < 500) { int b = (millis()/10)%20; neopixelWrite(PIN_ONBOARD, 0, 0, b); } 
  else { neopixelWrite(PIN_ONBOARD, 10, 0, 0); }

  if (sats_s == 0) ring.setPixelColor(0, ring.Color(255, 0, 0));       
  else if (sats_s < 4) ring.setPixelColor(0, ring.Color(255, 140, 0)); 
  else ring.setPixelColor(0, ring.Color(0, 255, 0));                   

  if ((currentStatus & 0x07) == 0x07) ring.setPixelColor(1, ring.Color(0, 255, 0)); 
  else ring.setPixelColor(1, ring.Color(200, 0, 255)); 

  if (currentBat > 3.8) ring.setPixelColor(2, ring.Color(0, 255, 0));
  else if (currentBat > 3.6) ring.setPixelColor(2, ring.Color(255, 100, 0));
  else ring.setPixelColor(2, ring.Color(255, 0, 0)); 

  if(bmpOK) ring.setPixelColor(3, 0); else ring.setPixelColor(3, ring.Color(255, 0, 255)); 
  ring.show();
}

void setup() {
  Serial.begin(115200); delay(3000);
  pinMode(PIN_ONBOARD, OUTPUT); neopixelWrite(PIN_ONBOARD, 50, 50, 50);
  ring.begin(); ring.setBrightness(50); ring.show();
  for(int i=0; i<4; i++) { ring.setPixelColor(i, ring.Color(255, 255, 255)); ring.show(); delay(100); }
  delay(200); ring.clear(); ring.show(); neopixelWrite(PIN_ONBOARD, 0, 0, 0);

  pinMode(BAT_PIN, INPUT); analogReadResolution(12); analogSetAttenuation(ADC_11db); 

  spiRadio.begin(PIN_SCK, PIN_MISO, PIN_MOSI, PIN_CSN);
  if (!radio.begin(&spiRadio)) { 
    for(int i=0; i<4; i++) ring.setPixelColor(i, ring.Color(255, 0, 0)); ring.show();
  } else {
    radio.openWritingPipe(address); radio.setChannel(108); radio.setDataRate(RF24_250KBPS); 
    radio.setPALevel(RF24_PA_MAX); radio.setRetries(15, 15); radio.setCRCLength(RF24_CRC_16); radio.stopListening();
  }

  Wire.begin(SDA_PIN, SCL_PIN);
  if(mpu.begin()) { mpu.setAccelerometerRange(MPU6050_RANGE_8_G); mpu.setGyroRange(MPU6050_RANGE_500_DEG); mpu.setFilterBandwidth(MPU6050_BAND_21_HZ); mpuOK = true; }
  
  for(int i=0; i<3; i++) { if(bmp.begin()) { bmpOK = true; break; } delay(100); }
  if(bmpOK) { float s=0; for(int i=0; i<20; i++){ s+=bmp.readAltitude(); delay(20); } altBase = s/20.0; altFus = altBase; altPrev = altBase; }

  GPS_Serial.begin(9600, SERIAL_8N1, RX_GPS_PIN, TX_GPS_PIN);
  dht.begin();
  prevTime = millis();
}

void loop() {
  unsigned long currentTime = millis();
  if (currentTime - lastPixelUpdate > 100) { updateLights(); lastPixelUpdate = currentTime; }

  while (GPS_Serial.available() > 0) gps.encode(GPS_Serial.read());
  if (gps.location.isUpdated()) { lat_s = gps.location.lat(); lon_s = gps.location.lng(); sats_s = gps.satellites.value(); hdop_s = gps.hdop.hdop(); gpsFix = true; }

  sensors_event_t a, g, temp; if(mpuOK) mpu.getEvent(&a, &g, &temp);
  float dt = (currentTime - prevTime) / 1000.0; prevTime = currentTime;
  float ax_deg = atan2(a.acceleration.y, a.acceleration.z) * RAD_TO_DEG; float ay_deg = atan2(-a.acceleration.x, sqrt(a.acceleration.y*a.acceleration.y + a.acceleration.z*a.acceleration.z)) * RAD_TO_DEG;
  float gx = g.gyro.x * RAD_TO_DEG - gx_off; float gy = g.gyro.y * RAD_TO_DEG - gy_off; float gz = g.gyro.z * RAD_TO_DEG - gz_off;
  roll  = 0.96 * (roll  + gx*dt) + 0.04 * ax_deg; pitch = 0.96 * (pitch + gy*dt) + 0.04 * ay_deg; yaw = gz; 

  static int counter = 0; counter++;

  pkgA.r = roll; pkgA.p = pitch; pkgA.y = yaw; pkgA.ax = a.acceleration.x; pkgA.ay = a.acceleration.y; pkgA.az = a.acceleration.z; pkgA.gx = gx;
  bool ok = radio.write(&pkgA, sizeof(pkgA)); 
  if (ok) lastAckTime = millis();

  if (counter % 20 == 0) {
    float rawAlt = 0, pBMP = 0, tBMP = 0;
    if(bmpOK) { rawAlt = bmp.readAltitude(); pBMP = bmp.readPressure(); tBMP = bmp.readTemperature(); }
    float delta = rawAlt - altPrev; altFus += delta; altPrev = rawAlt;
    if (currentTime - lastDHTTime > 2000) { float t = dht.readTemperature(); float h = dht.readHumidity(); if(!isnan(t)) tDHT_s = t; if(!isnan(h)) hDHT_s = h; lastDHTTime = currentTime; }

    pkgB.bat = readBattery(); currentBat = pkgB.bat; 
    pkgB.gy = gy; pkgB.gz = gz; pkgB.pres = pBMP; pkgB.alt = altFus - altBase; 
    pkgB.temp = (tDHT_s != 0) ? (tBMP + tDHT_s)/2.0 : tBMP; pkgB.hum = hDHT_s;
    pkgB.ram = getRamUsage();
    
    byte status = 0;
    if(mpuOK) status |= (1<<0); if(bmpOK) status |= (1<<1); if(!isnan(tDHT_s)) status |= (1<<2); if(gpsFix) status |= (1<<3);
    pkgB.status = status; currentStatus = status;
    
    radio.write(&pkgB, sizeof(pkgB)); 
  }

  if (counter % 50 == 0) { pkgC.lat = lat_s; pkgC.lon = lon_s; pkgC.sats = sats_s; pkgC.hdop = hdop_s; radio.write(&pkgC, sizeof(pkgC)); counter = 0; }
  delay(5); 
}