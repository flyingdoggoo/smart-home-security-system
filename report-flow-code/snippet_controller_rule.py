# Controller decision snippet (report-friendly)

if gas_alert:
    request_door("open", source="gas_escape")
elif label == "owner":
    request_door("open", source="face_owner")
elif label == "stranger":
    request_door("close", source="face_stranger")
