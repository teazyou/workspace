// Prints the current Wi-Fi link RSSI in dBm (negative int), or nothing if there
// is no Wi-Fi association. Reads the CURRENT link only — no scan — so it is cheap
// and non-disruptive. Used by plugins/wifi.sh for the strength icon.
import CoreWLAN

guard let iface = CWWiFiClient.shared().interface() else { exit(0) }
let rssi = iface.rssiValue()
if rssi != 0 { print(rssi) }
