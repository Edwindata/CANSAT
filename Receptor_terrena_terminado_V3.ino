
#include <SPI.h>
#include <RF24.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET    -1 
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

#define BUTTON_PIN 15
#define CE_PIN 4
#define CSN_PIN 5
#define LED_PIN 2 

RF24 radio(CE_PIN, CSN_PIN);
const byte address[6] = "SAT01";

int currentScreen = 0; int buttonState; int lastButtonState = HIGH; unsigned long lastDebounceTime = 0;  
int packetsCounter = 0; int signalQuality = 0; unsigned long lastSecTime = 0; float baseRamUsage = 0;
unsigned long ultimoPaqueteTime = 0; unsigned long lastDisplayUpdate = 0;

struct __attribute__((packed)) PacketA { byte id; float r, p, y, ax, ay, az, gx; };
struct __attribute__((packed)) PacketB { byte id; float bat; float gy, gz, pres, alt, temp, hum; byte ram; byte status; };
struct __attribute__((packed)) PacketC { byte id; float lat, lon; int sats; float hdop; };

float r=0, p=0, y=0, ax=0, ay=0, az=0, gx=0, gy=0, gz=0;
float pres=0, alt=0, temp=0, hum=0;
float lat=0, lon=0; int sats=0; float hdop=10.0;
int satRam = 0; byte satStatus = 0; float satBat = 0; 

void setup() {
  Serial.begin(921600);
  pinMode(LED_PIN, OUTPUT); pinMode(BUTTON_PIN, INPUT_PULLUP);
  Wire.begin(21, 22);
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { for(;;); }
  
  display.clearDisplay(); display.setTextColor(WHITE); display.setTextSize(1); display.setCursor(0, 10); display.println("BASE V25.0 READY"); display.display(); delay(1000);
  if (!radio.begin()) { while(1); }
  radio.openReadingPipe(0, address); radio.setChannel(108); radio.setDataRate(RF24_250KBPS); radio.setPALevel(RF24_PA_MAX); radio.setCRCLength(RF24_CRC_16); radio.startListening();
}

void loop() {
  if (radio.available()) {
    ultimoPaqueteTime = millis(); digitalWrite(LED_PIN, HIGH); packetsCounter++; 
    byte buffer[32]; radio.read(&buffer, sizeof(buffer)); byte id = buffer[0];
    
    if (id == 1) {
      PacketA* pkg = (PacketA*)buffer;
      r = pkg->r; p = pkg->p; y = pkg->y; ax = pkg->ax; ay = pkg->ay; az = pkg->az; gx = pkg->gx;
      imprimirDatosUSB();
    }
    else if (id == 2) {
      PacketB* pkg = (PacketB*)buffer;
      satBat = pkg->bat; 
      gy = pkg->gy; gz = pkg->gz; pres = pkg->pres; alt = pkg->alt; temp = pkg->temp; hum = pkg->hum;
      satRam = pkg->ram; satStatus = pkg->status; 
    }
    else if (id == 3) {
      PacketC* pkg = (PacketC*)buffer;
      lat = pkg->lat; lon = pkg->lon; sats = pkg->sats; hdop = pkg->hdop;
      imprimirGPSUSB();
    }
  }
  if (millis() - ultimoPaqueteTime > 200) digitalWrite(LED_PIN, LOW);

  if (millis() - lastSecTime > 1000) {
    signalQuality = map(packetsCounter, 0, 50, 0, 100); if (signalQuality > 100) signalQuality = 100;
    if (millis() - ultimoPaqueteTime > 1000) signalQuality = 0;
    uint32_t freeRam = ESP.getFreeHeap(); uint32_t totalRam = ESP.getHeapSize();
    baseRamUsage = 100.0 - ((float)freeRam / (float)totalRam * 100.0);
    packetsCounter = 0; lastSecTime = millis();
  }

  int reading = digitalRead(BUTTON_PIN);
  if (reading != lastButtonState) lastDebounceTime = millis();
  if ((millis() - lastDebounceTime) > 50) {
    if (reading != buttonState) {
      buttonState = reading;
      if (buttonState == LOW) {
        currentScreen++; if (currentScreen > 3) currentScreen = 0; 
        display.clearDisplay(); actualizarOLED();
      }
    }
  }
  lastButtonState = reading;
  if (millis() - lastDisplayUpdate > 100) { actualizarOLED(); lastDisplayUpdate = millis(); }
}

void actualizarOLED() {
  display.clearDisplay(); display.setTextSize(1); display.setTextColor(WHITE);
  display.setCursor(0, 0);
  if (currentScreen == 0) { display.print("GPS:"); display.print("+/-"); display.print(hdop * 5.0, 0); display.print("m"); }
  else if (currentScreen == 1) display.print("2. SENSOR"); 
  else if (currentScreen == 2) display.print("3. BASE STAT"); 
  else display.print("4. SAT HEALTH");
  display.setCursor(85, 0); if (millis() - ultimoPaqueteTime < 1000) display.print("LINK"); else display.print(" -- ");
  display.drawLine(0, 8, 128, 8, WHITE); display.setCursor(0, 12);

  if (currentScreen == 0) {
    display.print("Sats:"); display.print(sats);
    display.setCursor(0, 22); display.print("La:"); display.print(lat, 3); display.print(" Lo:"); display.print(lon, 3);
  } 
  else if (currentScreen == 1) {
    display.setCursor(0, 12); display.print("Alt:"); display.print(alt, 1); display.print("m "); display.print("  "); display.print("Temp:"); display.print(temp, 0); display.println("C");
    display.setCursor(0, 22); display.print("Pres:"); display.print(pres/100.0, 0); display.print("hPa"); display.print("  "); display.print("H:"); display.print(hum, 0); display.print("%");
  } 
  else if (currentScreen == 2) {
    display.print("RF:"); display.drawRect(20, 12, 60, 8, WHITE); int wRF = map(signalQuality, 0, 100, 0, 56); if(wRF>0) display.fillRect(22, 14, wRF, 4, WHITE); display.setCursor(85, 12); display.print(signalQuality); display.print("%");
    display.setCursor(0, 22); display.print("Sy:"); display.drawRect(20, 22, 60, 8, WHITE); int wRAM = map((int)baseRamUsage, 0, 100, 0, 56); if(wRAM>0) display.fillRect(22, 24, wRAM, 4, WHITE); display.setCursor(85, 22); display.print((int)baseRamUsage); display.print("%");
  }
  else { 
    display.print("Bat:"); display.print(satBat, 2); display.print("V");
    int pct = map((satBat*100), 300, 420, 0, 100); if(pct<0) pct=0; if(pct>100) pct=100;
    display.drawRect(65, 12, 35, 8, WHITE); int wBat = map(pct, 0, 100, 0, 31); if(wBat>0) display.fillRect(67, 14, wBat, 4, WHITE);
    display.setCursor(105, 12); display.print(pct); display.print("%");

    display.setCursor(0, 22); 
    display.print((satStatus&(1<<0))?"M":"."); display.print((satStatus&(1<<1))?"B":"."); 
    display.print((satStatus&(1<<2))?"D":"."); display.print((satStatus&(1<<3))?"G":"."); 
    display.print(" CHK:"); if(satStatus==15) display.print("OK"); else if(satStatus>=7) display.print("WAIT"); else display.print("ERR");
  }
  display.display();
}

void imprimirDatosUSB() {
  Serial.print("DATOS,"); Serial.print(r); Serial.print(","); Serial.print(p); Serial.print(","); Serial.print(y); Serial.print(",");
  Serial.print(ax); Serial.print(","); Serial.print(ay); Serial.print(","); Serial.print(az); Serial.print(",");
  Serial.print(gx); Serial.print(","); Serial.print(gy); Serial.print(","); Serial.print(gz); Serial.print(",");
  Serial.print(pres); Serial.print(","); Serial.print(alt); Serial.print(",");
  Serial.print(temp); Serial.print(","); Serial.print(hum); Serial.print(","); Serial.println(satBat); 
}

void imprimirGPSUSB() {
  Serial.print("GPS,"); Serial.print(lat, 6); Serial.print(","); Serial.print(lon, 6); Serial.print(",");
  Serial.print(sats); Serial.print(","); Serial.println(hdop); 
}