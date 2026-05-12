#include <WiFi.h>
#include <PubSubClient.h>
#include <ESP32Servo.h>

// ---------- WiFi ----------
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// ---------- MQTT ----------
const char* MQTT_HOST = "192.168.1.10";
const int MQTT_PORT = 1883;
const char* MQTT_CLIENT_ID = "esp32-io-node";

const char* TOPIC_DOOR_CMD = "home/io/cmd/door";
const char* TOPIC_LIGHT_CMD = "home/io/cmd/light";
const char* TOPIC_TELEMETRY = "home/io/telemetry";

// ---------- Hardware Pins ----------
const int SERVO_PIN = 14;
const int MQ2_PIN = 34;    // ADC1 pin, safe with WiFi
const int LIGHT_PIN = 2;
const int BUZZER_PIN = 15;

// ---------- Servo Angles ----------
const int SERVO_LOCK_ANGLE = 10;
const int SERVO_UNLOCK_ANGLE = 90;

// ---------- MQ-2 ----------
const int GAS_THRESHOLD = 1800;
const unsigned long TELEMETRY_INTERVAL_MS = 2000;

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
Servo doorServo;

String doorState = "locked";
String lightState = "off";
bool gasAlert = false;
unsigned long lastTelemetryMs = 0;

void setDoorLocked(bool locked) {
  if (locked) {
    doorServo.write(SERVO_LOCK_ANGLE);
    doorState = "locked";
  } else {
    doorServo.write(SERVO_UNLOCK_ANGLE);
    doorState = "unlocked";
  }
}

void setLight(bool on) {
  digitalWrite(LIGHT_PIN, on ? HIGH : LOW);
  lightState = on ? "on" : "off";
}

void publishTelemetry(int gasValue) {
  String payload = "{";
  payload += "\"gas_value\":" + String(gasValue);
  payload += ",\"gas_alert\":" + String(gasAlert ? "true" : "false");
  payload += ",\"door_state\":\"" + doorState + "\"";
  payload += ",\"light_state\":\"" + lightState + "\"";
  payload += ",\"source\":\"esp32_io\"";
  payload += "}";

  mqttClient.publish(TOPIC_TELEMETRY, payload.c_str(), true);
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg = "";
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();

  if (String(topic) == TOPIC_DOOR_CMD) {
    if (msg.equalsIgnoreCase("OPEN")) {
      setDoorLocked(false);
    } else if (msg.equalsIgnoreCase("CLOSE")) {
      if (!gasAlert) {
        setDoorLocked(true);
      }
    }
  } else if (String(topic) == TOPIC_LIGHT_CMD) {
    if (msg.equalsIgnoreCase("ON")) {
      setLight(true);
    } else if (msg.equalsIgnoreCase("OFF")) {
      setLight(false);
    }
  }
}

void ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
}

void ensureMqtt() {
  while (!mqttClient.connected()) {
    String clientId = String(MQTT_CLIENT_ID) + "-" + String(random(0xffff), HEX);
    if (mqttClient.connect(clientId.c_str())) {
      mqttClient.subscribe(TOPIC_DOOR_CMD, 1);
      mqttClient.subscribe(TOPIC_LIGHT_CMD, 1);
    } else {
      delay(1000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(LIGHT_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  setLight(false);
  digitalWrite(BUZZER_PIN, LOW);

  doorServo.setPeriodHertz(50);
  doorServo.attach(SERVO_PIN);
  setDoorLocked(true);

  ensureWiFi();
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
}

void loop() {
  ensureWiFi();
  ensureMqtt();
  mqttClient.loop();

  int gasValue = analogRead(MQ2_PIN);
  gasAlert = gasValue >= GAS_THRESHOLD;

  // Emergency policy: open door when gas alert is active
  if (gasAlert) {
    setDoorLocked(false);
    digitalWrite(BUZZER_PIN, HIGH);
  } else {
    digitalWrite(BUZZER_PIN, LOW);
  }

  unsigned long now = millis();
  if (now - lastTelemetryMs >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryMs = now;
    publishTelemetry(gasValue);
  }
}

