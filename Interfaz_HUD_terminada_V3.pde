
import processing.serial.*;
import java.util.ArrayList; 

String apiKey = "You_API_Key"; 

int serialPortIndex = 0; 

int viewMode = 0; // 0=3D, 1=Mapa, 2=Gráficas
Serial myPort;
PImage mapa; 
boolean cargandoMapa = false;
long ultimoMapaTime = 0; 

ArrayList<String> rutaLat = new ArrayList<String>();
ArrayList<String> rutaLon = new ArrayList<String>();
float lastLatNum=0, lastLonNum=0; 
long lastGPSTime = 0; 

ArrayList<Float> hAlt = new ArrayList<Float>();
ArrayList<Float> hTemp = new ArrayList<Float>();
ArrayList<Float> hHum = new ArrayList<Float>(); // Humedad
ArrayList<Float> hPres = new ArrayList<Float>();
int maxPoints = 300; 
long lastGraphTime = 0; 

int estadoMedicion = 0; 
PVector posInicio = new PVector(0,0);
PVector posFinal = new PVector(0,0);
PVector lastPosRecorded = new PVector(0,0); 
float distanciaRecorrida = 0.0;

float currentRoll, currentPitch, currentYaw, targetRoll, targetPitch, targetYaw;
float smoothFactor = 0.15;
float accX, accY, accZ, gyroX, gyroY, gyroZ; 
float presion, alturaRelativa, temperatura, humedad;
float satBattery = 0; 
String latitudActual = "0", longitudActual = "0"; 
int satelites = 0; float gpsError = 0; boolean gpsSignal = false; 

int cylinderSides = 40;
float cylinderRadius = 30, cylinderHeight = 100, boundingBoxSize = 300; 
float camRotX = -0.7, camRotY = -0.7, camDist = 250; 
int toggleX = 20, toggleY, toggleSize = 50;
int measureX = 100, measureY, measureW = 120, measureH = 50; 

void setup() {
  size(1000, 800, P3D); 
  frameRate(60); 
  toggleY = height - (toggleSize + 20);
  measureY = height - (measureH + 20); 

  PFont font = createFont("Arial Bold", 14); textFont(font);

  printArray(Serial.list());
  try {
    // Asegúrate que el índice coincida con tu puerto real
    String portName = Serial.list()[serialPortIndex]; 
    myPort = new Serial(this, portName, 921600);
    myPort.bufferUntil('\n');
    println("--> CONECTADO A: " + portName);
  } catch (Exception e) { println("ERROR PUERTO"); exit(); }
  
  thread("solicitarNuevoMapa");
}

void draw() {
  currentRoll = lerp(currentRoll, targetRoll, smoothFactor);
  currentPitch = lerp(currentPitch, targetPitch, smoothFactor);
  currentYaw = lerp(currentYaw, targetYaw, smoothFactor);

  if (viewMode == 2) {
    drawGraphsView(); 
  } else {
    background(30, 30, 40); 
    if (viewMode == 0) {
      draw3DScene(); 
      drawHUD();      
    } else {
      drawMapView();
    }
  }
  
  drawToggleIcon();
  if (viewMode == 1) drawMeasureButton();
}


void drawGraphsView() {
  hint(DISABLE_DEPTH_TEST); camera(); noLights();
  background(20); 
  float hGraph = (height - 80) / 4.0;
  float wGraph = width - 120;
  
  drawSingleGraph(hAlt, "ALTURA (m)", 60, 50, wGraph, hGraph-20, color(0, 255, 255));
  drawSingleGraph(hTemp, "TEMPERATURA (C)", 60, 50 + hGraph, wGraph, hGraph-20, color(255, 100, 100));
  drawSingleGraph(hHum, "HUMEDAD (%)", 60, 50 + hGraph*2, wGraph, hGraph-20, color(100, 200, 255));
  drawSingleGraph(hPres, "PRESIÓN (Pa)", 60, 50 + hGraph*3, wGraph, hGraph-20, color(100, 255, 100));
  
  fill(255); textAlign(CENTER); textSize(16); text("MONITOR EN TIEMPO REAL (1 min/div)", width/2, 25);
  hint(ENABLE_DEPTH_TEST);
}

void drawSingleGraph(ArrayList<Float> data, String title, float x, float y, float w, float h, int c) {
  stroke(80); noFill(); rect(x, y, w, h);
  fill(255); textSize(12); textAlign(LEFT); text(title, x, y - 5);
  if(data.size() > 0) { textAlign(RIGHT); fill(c); text(nf(data.get(data.size()-1), 0, 2), x+w, y-5); }
  if (data.size() < 2) return;
  
  float minV = data.get(0); float maxV = data.get(0);
  int startIndex = max(0, data.size() - maxPoints);
  
  for (int i = startIndex; i < data.size(); i++) { float val = data.get(i); if (val < minV) minV = val; if (val > maxV) maxV = val; }
  float range = maxV - minV; if(range == 0) range = 1; minV -= range * 0.1; maxV += range * 0.1;
  
  stroke(c); strokeWeight(1.5); noFill(); beginShape();
  for (int i = startIndex; i < data.size(); i++) {
    float val = data.get(i); 
    float px = map(i, startIndex, max(startIndex + maxPoints -1, data.size()-1), x, x+w); 
    float py = map(val, minV, maxV, y+h, y); 
    vertex(px, py);
  }
  endShape();
  
  fill(150); textSize(9); textAlign(RIGHT); text(nf(maxV, 0, 1), x-5, y + 10); text(nf(minV, 0, 1), x-5, y + h);
  
  if (mouseX > x && mouseX < x+w && mouseY > y && mouseY < y+h) {
    int index = int(map(mouseX, x, x+w, startIndex, max(startIndex + maxPoints -1, data.size()-1)));
    if (index >= 0 && index < data.size()) {
      float val = data.get(index); 
      float px = map(index, startIndex, max(startIndex + maxPoints -1, data.size()-1), x, x+w); 
      float py = map(val, minV, maxV, y+h, y);
      stroke(150); line(px, y, px, y+h); fill(255); noStroke(); ellipse(px, py, 5, 5);
      fill(0, 200); rect(px+10, py-20, 60, 15); fill(255); textAlign(LEFT); text(nf(val, 0, 2), px+15, py-8);
    }
  }
}


void draw3DScene() {
  hint(ENABLE_DEPTH_TEST); lights(); 
  pushMatrix(); translate(width/2, height/2, -camDist); rotateX(camRotX); rotateY(camRotY); translate(-boundingBoxSize/2, boundingBoxSize/2, -boundingBoxSize/2);
  drawAxes(); 
  pushMatrix(); translate(boundingBoxSize/2, -cylinderHeight/2, boundingBoxSize/2); rotateY(radians(-currentYaw)); rotateX(radians(currentPitch)); rotateZ(radians(currentRoll)); noStroke(); fill(100, 150, 250); drawCylinder(cylinderRadius, cylinderHeight, cylinderSides); popMatrix(); popMatrix();
}

void drawHUD() {
  hint(DISABLE_DEPTH_TEST); camera(); noLights(); int margin = 40;
  fill(255); textSize(16); textAlign(LEFT); text("MPU6050 (GIROSCOPIO)", margin, 40); 
  textSize(14); fill(200);
  text("ROLL:  " + nf(targetRoll, 1, 2) + "°", margin, 70);
  text("PITCH: " + nf(targetPitch, 1, 2) + "°", margin, 90);
  text("YAW:   " + nf(targetYaw, 1, 2) + "°", margin, 110);
  text("ACC: X:" + nf(accX, 1, 1) + " Y:" + nf(accY, 1, 1) + " Z:" + nf(accZ, 1, 1), margin, 140);
  text("GYR: X:" + nf(gyroX, 1, 1) + " Y:" + nf(gyroY, 1, 1) + " Z:" + nf(gyroZ, 1, 1), margin, 160);

  int yBase = height - 100; 
  fill(255); textSize(16); text("AMBIENTE", margin, yBase - 30);
  textSize(14); fill(100, 255, 100); 
  text("TEMP:    " + nf(temperatura, 1, 1) + " C", margin, yBase);
  text("HUMEDAD: " + nf(humedad, 1, 0) + " %", margin, yBase + 20);
  fill(100, 200, 255); 
  text("PRESIÓN: " + nf(presion, 1, 0) + " Pa", margin + 180, yBase);
  text("ALTURA:  " + nf(alturaRelativa, 1, 2) + " m", margin + 180, yBase + 20);

  textAlign(RIGHT); int rightMargin = width - 40;
  fill(255); textSize(16); text("ESTADO GPS", rightMargin, 40); textSize(14);
  if (satelites >= 4) { fill(100, 255, 100); text("SEÑAL: EXCELENTE (3D)", rightMargin, 70); }
  else if (satelites > 0) { fill(255, 255, 0); text("SEÑAL: POBRE (2D)", rightMargin, 70); }
  else { fill(255, 50, 50); text("SEÑAL: SIN CONEXIÓN", rightMargin, 70); }
  fill(200); text("Sats: " + satelites, rightMargin, 90);
  if (gpsSignal) text("CORRECCIÓN ALTURA: ACTIVA", rightMargin, 120); else text("CORRECCIÓN ALTURA: ESPERANDO", rightMargin, 120);

  fill(255); textSize(16); text("SAT POWER", rightMargin, yBase - 30);
  if(satBattery > 3.8) fill(100, 255, 100); else if(satBattery > 3.5) fill(255, 255, 0); else fill(255, 50, 50);
  textSize(22); text(nf(satBattery, 1, 2) + " V", rightMargin, yBase);
  int pct = int(map(satBattery, 3.0, 4.2, 0, 100)); if(pct>100) pct=100; if(pct<0) pct=0;
  textSize(14); fill(200); text("Carga: " + pct + "%", rightMargin, yBase + 20);

  hint(ENABLE_DEPTH_TEST); 
}


void drawMapView() {
  hint(DISABLE_DEPTH_TEST); noLights(); camera(); background(0); 
  if (mapa != null) image(mapa, 0, 0, width, height);
  else { textAlign(CENTER); fill(255); textSize(16); text("Esperando GPS...", width/2, height/2); text("(R para forzar)", width/2, height/2 + 30); }

  fill(0, 0, 0, 180); noStroke(); rect(10, 10, 280, 120, 10); 
  fill(255); textAlign(LEFT, TOP); textSize(14); text("GPS Hardware (NEO-6M):", 20, 20);
  fill(200); textSize(12); text("Lat: " + latitudActual, 20, 45); text("Lon: " + longitudActual, 20, 60);
  if (satelites < 4) { fill(255, 255, 0); text("Sats: " + satelites, 20, 80); } else { fill(50, 255, 50); text("Sats: " + satelites + " (OK)", 20, 80); }
  fill(200, 200, 255); text("Error: +/- " + nf(gpsError, 1, 1) + " m", 20, 100);

  if (estadoMedicion == 1) {
    fill(255, 140, 0); textAlign(CENTER); textSize(20);
    text(">> GRABANDO RUTA: " + nf(distanciaRecorrida, 0, 1) + " m <<", width/2, 50);
    textSize(12); text("(Puntos: " + rutaLat.size() + ")", width/2, 70);
  } else if (estadoMedicion == 2) {
    fill(100, 255, 100); textAlign(CENTER); textSize(20);
    text("DISTANCIA TOTAL: " + nf(distanciaRecorrida, 0, 2) + " m", width/2, 50);
    textSize(12); text("Ruta Finalizada", width/2, 70);
  }

  if (cargandoMapa) { fill(255, 255, 0); textAlign(RIGHT); text("Descargando...", width-10, height-10); }
  hint(ENABLE_DEPTH_TEST);
}


void serialEvent(Serial p) {
  String data = p.readStringUntil('\n');
  if (data != null) {
    data = trim(data);
    if (data.startsWith("DATOS,")) { 
      String[] v = split(data.substring(6), ',');
      if (v.length >= 14) { 
          try {
            targetRoll=float(v[0]); targetPitch=float(v[1]); targetYaw=float(v[2]);
            accX=float(v[3]); accY=float(v[4]); accZ=float(v[5]); gyroX=float(v[6]); gyroY=float(v[7]); gyroZ=float(v[8]);
            presion=float(v[9]); alturaRelativa=float(v[10]); temperatura=float(v[11]); humedad=float(v[12]); satBattery=float(v[13]); 
            
            // --- GRÁFICAS: AHORA CADA 60 SEGUNDOS (1 MINUTO) ---
            if (millis() - lastGraphTime > 1000) {
              hAlt.add(alturaRelativa); hTemp.add(temperatura); hHum.add(humedad); hPres.add(presion);
              if(hAlt.size() > maxPoints * 2) { hAlt.remove(0); hTemp.remove(0); hHum.remove(0); hPres.remove(0); }
              lastGraphTime = millis();
            }
          } catch(Exception e) {}
      }
    } else if (data.startsWith("GPS,")) {
      String[] v = split(data.substring(4), ',');
      if (v.length >= 4) {
        latitudActual = v[0]; longitudActual = v[1]; satelites = int(v[2]); gpsError = float(v[3]) * 5.0;
        float latVal = float(latitudActual); float lonVal = float(longitudActual);
        
        if (abs(latVal) > 0.001) {
          gpsSignal = true;
          // --- FIX CRASH: GRABACIÓN CADA 5 SEGUNDOS ---
          if (estadoMedicion == 1 && millis() - lastGPSTime > 5000) {
              // SYNCHRONIZED: Protege la lista de colisiones con el hilo del mapa
              synchronized(rutaLat) {
                  if (distanciaRecorrida == 0 && rutaLat.size() == 0) { 
                      rutaLat.add(latitudActual); rutaLon.add(longitudActual); lastLatNum = latVal; lastLonNum = lonVal; 
                  } else { 
                      float distStep = haversine(lastLatNum, lastLonNum, latVal, lonVal); 
                      if (distStep > 2.0) { // Solo guarda si nos movemos > 2m
                          distanciaRecorrida += distStep; 
                          rutaLat.add(latitudActual); rutaLon.add(longitudActual); 
                          lastLatNum = latVal; lastLonNum = lonVal; 
                      } 
                  }
              }
              lastGPSTime = millis();
          }
        }
        
        if (!cargandoMapa && (millis() - ultimoMapaTime > 20000) && gpsSignal && estadoMedicion != 2) {
           thread("solicitarNuevoMapa"); ultimoMapaTime = millis(); 
        }
      }
    }
  }
}

void solicitarNuevoMapa() {
  cargandoMapa = true;
  String lat = gpsSignal ? latitudActual : "20.960841"; String lon = gpsSignal ? longitudActual : "-101.297977"; String url = "";
  
  if ((estadoMedicion == 1 || estadoMedicion == 2) && rutaLat.size() > 1) {
    String pathStr = "&path=color:0xff0000|weight:5";
    
    // SYNCHRONIZED: Protege la lectura mientras serialEvent podría estar escribiendo
    synchronized(rutaLat) {
        int paso = 1; if (rutaLat.size() > 60) paso = 2; if (rutaLat.size() > 120) paso = 4; if (rutaLat.size() > 300) paso = 10;
        for (int i = 0; i < rutaLat.size(); i += paso) { pathStr += "|" + rutaLat.get(i) + "," + rutaLon.get(i); }
        // Asegurar ultimo punto
        if(rutaLat.size() > 0) pathStr += "|" + rutaLat.get(rutaLat.size()-1) + "," + rutaLon.get(rutaLat.size()-1);
    }
    
    url = "http://maps.googleapis.com/maps/api/staticmap?size=600x600&maptype=roadmap" + pathStr + "&markers=label:I|" + posInicio.x + "," + posInicio.y + "&markers=label:F|" + lat + "," + lon + "&key=" + apiKey;
  } else {
    url = "http://maps.googleapis.com/maps/api/staticmap?center=" + lat + "," + lon + "&zoom=18&size=600x600&maptype=roadmap&markers=color:blue%7C" + lat + "," + lon + "&key=" + apiKey;
  }
  
  try { 
      java.net.URL u = new java.net.URL(url); 
      java.net.URLConnection c = u.openConnection(); 
      c.setRequestProperty("User-Agent", "Mozilla/5.0"); 
      c.setConnectTimeout(5000); 
      java.io.InputStream is = c.getInputStream(); 
      byte[] bytes = loadBytes(is); 
      if (bytes != null) { 
          PImage temp = createImage(600, 600, ARGB); 
          temp = loadImage(url, "png"); 
          if (temp != null) { mapa = temp; mapa.resize(width, height); } 
      } 
  } catch (Exception e) {} 
  cargandoMapa = false;
}

float haversine(float lat1, float lon1, float lat2, float lon2) { float R = 6371000.0; float dLat = radians(lat2 - lat1); float dLon = radians(lon2 - lon1); float a = sin(dLat/2) * sin(dLat/2) + cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon/2) * sin(dLon/2); float c = 2 * atan2(sqrt(a), sqrt(1-a)); return R * c; }
void drawMeasureButton() { hint(DISABLE_DEPTH_TEST); camera(); noLights(); if (estadoMedicion == 0) fill(100); else if (estadoMedicion == 1) fill(255, 140, 0); else fill(50, 200, 50); stroke(255); strokeWeight(2); rect(measureX, measureY, measureW, measureH, 5); fill(255); textAlign(CENTER, CENTER); textSize(14); if (estadoMedicion == 0) text("INICIAR RUTA", measureX + measureW/2, measureY + measureH/2); else if (estadoMedicion == 1) text("TERMINAR", measureX + measureW/2, measureY + measureH/2); else text("REINICIAR", measureX + measureW/2, measureY + measureH/2); hint(ENABLE_DEPTH_TEST); }
void drawToggleIcon() { hint(DISABLE_DEPTH_TEST); camera(); noLights(); stroke(255); fill(50, 200); rect(toggleX, toggleY, toggleSize, toggleSize, 5); fill(255); textAlign(CENTER,CENTER); String lbl = "3D"; if(viewMode==1) lbl="MAP"; if(viewMode==2) lbl="GRA"; text(lbl, toggleX+25, toggleY+25); hint(ENABLE_DEPTH_TEST); }
void mousePressed() { if (mouseX > toggleX && mouseX < toggleX+toggleSize && mouseY > toggleY && mouseY < toggleY+toggleSize) { viewMode++; if(viewMode>2) viewMode=0; } if (viewMode == 1 && mouseX > measureX && mouseX < measureX+measureW && mouseY > measureY && mouseY < measureY+measureH) { if (estadoMedicion == 0) { if (gpsSignal) { posInicio.set(float(latitudActual), float(longitudActual)); distanciaRecorrida = 0; synchronized(rutaLat) { rutaLat.clear(); rutaLon.clear(); rutaLat.add(latitudActual); rutaLon.add(longitudActual); } lastLatNum = float(latitudActual); lastLonNum = float(longitudActual); estadoMedicion = 1; thread("solicitarNuevoMapa"); } else println("ERROR: Sin GPS"); } else if (estadoMedicion == 1) { if (gpsSignal) { posFinal.set(float(latitudActual), float(longitudActual)); estadoMedicion = 2; thread("solicitarNuevoMapa"); } } else if (estadoMedicion == 2) { estadoMedicion = 0; thread("solicitarNuevoMapa"); } } }
void mouseDragged() { if (viewMode==0) { camRotY += (mouseX-pmouseX)*0.01; camRotX += (mouseY-pmouseY)*0.01; } }
void mouseWheel(MouseEvent e) { if (viewMode==0) camDist += e.getCount()*20; }
void keyPressed() { if (key == 'r' || key == 'R') thread("solicitarNuevoMapa"); }
void drawAxes() { drawGridXY(boundingBoxSize, 30, color(80)); drawGridXZ(boundingBoxSize, 30, color(80)); drawGridYZ(boundingBoxSize, 30, color(80)); strokeWeight(3); float L = boundingBoxSize + 50; stroke(255,0,0); line(0,0,0, L,0,0); stroke(0,255,0); line(0,0,0, 0,-L,0); stroke(0,0,255); line(0,0,0, 0,0,L); }
void drawCylinder(float r, float h, int s) { float a=TWO_PI/s; beginShape(QUAD_STRIP); for(int i=0; i<=s; i++) { vertex(r*cos(i*a), -h/2, r*sin(i*a)); vertex(r*cos(i*a), h/2, r*sin(i*a)); } endShape(); beginShape(TRIANGLE_FAN); vertex(0,-h/2,0); for(int i=0;i<=s;i++) vertex(r*cos(i*a),-h/2,r*sin(i*a)); endShape(); beginShape(TRIANGLE_FAN); vertex(0,h/2,0); for(int i=0;i<=s;i++) vertex(r*cos(i*a),h/2,r*sin(i*a)); endShape(); }
void drawGridXY(float s, float st, int c) { stroke(c); strokeWeight(1); for(float i=0; i<=s; i+=st) { line(i,0,0, i,-s,0); line(0,-i,0, s,-i,0); } }
void drawGridXZ(float s, float st, int c) { stroke(c); strokeWeight(1); for(float i=0; i<=s; i+=st) { line(i,0,0, i,0,s); line(0,0,i, s,0,i); } }
void drawGridYZ(float s, float st, int c) { stroke(c); strokeWeight(1); for(float i=0; i<=s; i+=st) { line(0,-i,0, 0,-i,s); line(0,0,i, 0,-s,i); } }
