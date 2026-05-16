// Telemetry publish snippet (report-friendly)
String payload = "{";
payload += "\"gas_value\":" + String(gasRaw);
payload += ",\"gas_alert\":" + String(gasAlert ? "true" : "false");
payload += ",\"light_value\":" + String(lightRaw);
payload += ",\"door_state\":\"" + doorState + "\"";
payload += ",\"light_state\":\"" + lightState + "\"";
payload += "}";
mqttClient.publish(TOPIC_TELEMETRY, payload.c_str(), true);
