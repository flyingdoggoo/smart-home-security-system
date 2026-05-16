#include <WiFi.h>
#include <PubSubClient.h>
#include <ESP32Servo.h>

/*
  ESP32-C3 main controller
  - MQ2: read A0 (value) + D0 (threshold trigger)
  - Light sensor: read A0/D0, auto turn ON/OFF LED when dark
  - Receive web commands via MQTT for door/light
  - Publish telemetry to backend/web

  Pin map (ESP32-C3-DevKitM-1):
  - Servo SIG: GPIO7
  - MQ2 A0: GPIO0 (MUST use divider if MQ2 VCC=5V)
  - MQ2 D0: GPIO6 (MUST use divider if MQ2 VCC=5V)
  - Light A0: GPIO1
  - Light D0: GPIO3
  - Light LED: GPIO4
  - Buzzer: GPIO5
*/

// ---------- WiFi ----------
const char *WIFI_SSID = "Veitel";
const char *WIFI_PASSWORD = "12345667";

// ---------- MQTT ----------
const char *MQTT_HOST = "10.104.86.2";
const int MQTT_PORT = 1883;
const char *MQTT_CLIENT_ID = "esp32-c3-io-node";

const char *TOPIC_DOOR_CMD = "home/io/cmd/door";
const char *TOPIC_LIGHT_CMD = "home/io/cmd/light";
const char *TOPIC_TELEMETRY = "home/io/telemetry";

// ---------- Pin Mapping ----------
const int SERVO_PIN = 7;
const int MQ2_A0_PIN = 0;     // ADC1_CH0
const int MQ2_D0_PIN = 6;     // digital threshold
const int LIGHT_A0_PIN = 1;   // ADC1_CH1
const int LIGHT_D0_PIN = 3;   // digital threshold
const int LIGHT_LED_PIN = 4; // room light
const int BUZZER_PIN = 5;

// ---------- Sensor Logic ----------
// Most LM393 modules output LOW when threshold is triggered.
const bool MQ2_D0_ACTIVE_LOW = true;
const bool LIGHT_D0_DARK_LOW = true;
const bool LIGHT_LED_ACTIVE_HIGH = true;
const bool BUZZER_ACTIVE_HIGH = true;

// ---------- Thresholds ----------
// Tune these from Serial output.
const int GAS_THRESHOLD = 1700;
const int LIGHT_DARK_THRESHOLD = 2000;
const bool LIGHT_DARK_WHEN_ANALOG_HIGH = true;
const int LIGHT_HYSTERESIS = 150;

// ---------- Behavior ----------
const bool USE_MQ2_D0_FOR_ALERT = true;
const bool USE_LIGHT_D0_FOR_DARK = false;
const bool USE_BOTH_LIGHT_SOURCES_FOR_DARK = false;

const char *FW_VERSION = "esp32-io-node-2026-05-16-02";

const int SERVO_LOCK_ANGLE = 10;
const int SERVO_UNLOCK_ANGLE = 90;

const unsigned long SENSOR_READ_INTERVAL_MS = 300;
const unsigned long TELEMETRY_INTERVAL_MS = 2000;
const unsigned long DEBUG_PRINT_INTERVAL_MS = 2000;
const unsigned long LIGHT_OVERRIDE_TIMEOUT_MS = 5UL * 60UL * 1000UL;

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
Servo doorServo;

String doorState = "locked";
String lightState = "off";

bool gasAlert = false;
bool darkDetected = false;
bool manualLightOverride = false;
bool manualLightOn = false;

int gasRaw = 0;
int lightRaw = 0;
int gasDigital = HIGH;
int lightDigital = HIGH;
bool darkByAnalogState = false;
bool darkByD0State = false;

unsigned long lastSensorReadMs = 0;
unsigned long lastTelemetryMs = 0;
unsigned long lastDebugMs = 0;
unsigned long manualLightUntilMs = 0;

void setPinActiveLevel(int pin, bool active, bool activeHigh) {
  if (pin < 0) {
    return;
  }
  int level = active ? (activeHigh ? HIGH : LOW) : (activeHigh ? LOW : HIGH);
  digitalWrite(pin, level);
}

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
  setPinActiveLevel(LIGHT_LED_PIN, on, LIGHT_LED_ACTIVE_HIGH);
  lightState = on ? "on" : "off";
}

void setGasAlarmOutputs(bool on) {
  setPinActiveLevel(BUZZER_PIN, on, BUZZER_ACTIVE_HIGH);
}

void setManualLightOverride(bool enabled, bool on) {
  manualLightOverride = enabled;
  manualLightOn = on;
  if (enabled) {
    manualLightUntilMs = millis() + LIGHT_OVERRIDE_TIMEOUT_MS;
    setLight(on);
  }
}

bool isMq2D0Triggered() {
  return MQ2_D0_ACTIVE_LOW ? (gasDigital == LOW) : (gasDigital == HIGH);
}

bool isLightD0Dark() {
  return LIGHT_D0_DARK_LOW ? (lightDigital == LOW) : (lightDigital == HIGH);
}

bool isLightAnalogDark() {
  int onThr = LIGHT_DARK_THRESHOLD;
  int offThr = LIGHT_DARK_WHEN_ANALOG_HIGH ? (LIGHT_DARK_THRESHOLD - LIGHT_HYSTERESIS)
                                           : (LIGHT_DARK_THRESHOLD + LIGHT_HYSTERESIS);

  if (LIGHT_DARK_WHEN_ANALOG_HIGH) {
    if (darkByAnalogState) {
      return lightRaw >= offThr;
    }
    return lightRaw >= onThr;
  }

  if (darkByAnalogState) {
    return lightRaw <= offThr;
  }
  return lightRaw <= onThr;
}

void applyAutoLightLogic() {
  // Dark condition has priority: always turn light ON
  // even if there was a recent manual OFF command.
  if (darkDetected) {
    setLight(true);
    return;
  }

  if (manualLightOverride) {
    if ((long)(millis() - manualLightUntilMs) >= 0) {
      manualLightOverride = false;
    } else {
      setLight(manualLightOn);
      return;
    }
  }

  setLight(darkDetected);
}

void updateSensorReadings() {
  int currentGasRaw = analogRead(MQ2_A0_PIN);
  int currentLightRaw = analogRead(LIGHT_A0_PIN);
  gasDigital = digitalRead(MQ2_D0_PIN);
  lightDigital = digitalRead(LIGHT_D0_PIN);

  // Smooth analog values so web chart/status is more stable
  gasRaw = (gasRaw == 0) ? currentGasRaw : ((gasRaw * 3 + currentGasRaw) / 4);
  lightRaw = (lightRaw == 0) ? currentLightRaw : ((lightRaw * 3 + currentLightRaw) / 4);

  bool gasByAnalog = gasRaw >= GAS_THRESHOLD;
  bool gasByD0 = isMq2D0Triggered();
  gasAlert = USE_MQ2_D0_FOR_ALERT ? (gasByAnalog || gasByD0) : gasByAnalog;

  bool darkByAnalog = isLightAnalogDark();
  bool darkByD0 = isLightD0Dark();
  darkByAnalogState = darkByAnalog;
  darkByD0State = darkByD0;
  if (USE_BOTH_LIGHT_SOURCES_FOR_DARK) {
    darkDetected = darkByD0 || darkByAnalog;
  } else {
    darkDetected = USE_LIGHT_D0_FOR_DARK ? darkByD0 : darkByAnalog;
  }

  if (gasAlert && doorState != "unlocked") {
    setDoorLocked(false); // escape policy
  }

  setGasAlarmOutputs(gasAlert);
  applyAutoLightLogic();
}

void publishTelemetry() {
  String payload = "{";
  payload += "\"gas_value\":" + String(gasRaw);
  payload += ",\"gas_alert\":" + String(gasAlert ? "true" : "false");
  payload += ",\"gas_d0\":" + String(isMq2D0Triggered() ? "true" : "false");
  payload += ",\"light_value\":" + String(lightRaw);
  payload += ",\"dark\":" + String(darkDetected ? "true" : "false");
  payload += ",\"light_d0_dark\":" + String(isLightD0Dark() ? "true" : "false");
  payload += ",\"door_state\":\"" + doorState + "\"";
  payload += ",\"light_state\":\"" + lightState + "\"";
  payload += ",\"source\":\"esp32_c3_io\"";
  payload += "}";
  mqttClient.publish(TOPIC_TELEMETRY, payload.c_str(), true);
}

void mqttCallback(char *topic, byte *payload, unsigned int length) {
  String msg = "";
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();
  msg.toUpperCase();
  String topicStr(topic);

  if (topicStr == TOPIC_DOOR_CMD) {
    if (msg == "OPEN") {
      setDoorLocked(false);
      Serial.println("[CMD] door OPEN");
    } else if (msg == "CLOSE") {
      if (!gasAlert) {
        setDoorLocked(true);
        Serial.println("[CMD] door CLOSE");
      }
    }
  } else if (topicStr == TOPIC_LIGHT_CMD) {
    if (msg == "ON") {
      setManualLightOverride(true, true);
      Serial.println("[CMD] light ON (manual override)");
    } else if (msg == "OFF") {
      setManualLightOverride(true, false);
      Serial.println("[CMD] light OFF (manual override)");
    } else if (msg == "AUTO") {
      manualLightOverride = false;
      Serial.println("[CMD] light AUTO");
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
    String clientId = String(MQTT_CLIENT_ID) + "-" + String(random(0xFFFF), HEX);
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
  Serial.printf("\n[BOOT] %s\n", FW_VERSION);
  Serial.printf("[CFG] LIGHT_DARK_THRESHOLD=%d LIGHT_HYSTERESIS=%d\n",
                LIGHT_DARK_THRESHOLD, LIGHT_HYSTERESIS);
  Serial.printf("[CFG] LIGHT_DARK_WHEN_ANALOG_HIGH=%d USE_LIGHT_D0_FOR_DARK=%d USE_BOTH_LIGHT_SOURCES_FOR_DARK=%d\n",
                LIGHT_DARK_WHEN_ANALOG_HIGH ? 1 : 0,
                USE_LIGHT_D0_FOR_DARK ? 1 : 0,
                USE_BOTH_LIGHT_SOURCES_FOR_DARK ? 1 : 0);

  pinMode(MQ2_D0_PIN, INPUT);
  pinMode(LIGHT_D0_PIN, INPUT);
  pinMode(LIGHT_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  setLight(false);
  setGasAlarmOutputs(false);

  analogSetPinAttenuation(MQ2_A0_PIN, ADC_11db);
  analogSetPinAttenuation(LIGHT_A0_PIN, ADC_11db);

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

  unsigned long now = millis();

  if (now - lastSensorReadMs >= SENSOR_READ_INTERVAL_MS) {
    lastSensorReadMs = now;
    updateSensorReadings();
  }

  if (now - lastTelemetryMs >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryMs = now;
    publishTelemetry();
  }

  if (now - lastDebugMs >= DEBUG_PRINT_INTERVAL_MS) {
    lastDebugMs = now;
    Serial.printf(
      "[SENSOR] gasRaw=%d gasD0=%d gasAlert=%d | lightRaw=%d thr=%d hys=%d lightD0=%d darkA0=%d darkD0=%d dark=%d | override=%d manualOn=%d | door=%s light=%s\n",
      gasRaw, gasDigital, gasAlert ? 1 : 0, lightRaw, LIGHT_DARK_THRESHOLD, LIGHT_HYSTERESIS, lightDigital,
      darkByAnalogState ? 1 : 0, darkByD0State ? 1 : 0, darkDetected ? 1 : 0, manualLightOverride ? 1 : 0, manualLightOn ? 1 : 0,
      doorState.c_str(), lightState.c_str());
  }
}
