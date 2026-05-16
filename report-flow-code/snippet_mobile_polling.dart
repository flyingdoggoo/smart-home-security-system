// Polling snippet from mobile app architecture
_timer = Timer.periodic(const Duration(seconds: 2), (_) async {
  final status = await api.getStatus();
  // update UI model
});

Future<void> setLight(String action) async {
  await api.setLight(action); // /actions/light/on|off
  await refresh();
}
