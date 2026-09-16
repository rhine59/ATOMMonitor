import SwiftUI
struct StationDetailView:View{
 let station:ATOMStation
 var body:some View{List{
  Section("Health"){LabeledContent("Status",value:station.health.title);LabeledContent("Last heartbeat",value:relative(station.lastHeartbeat))}
  Section("Location"){LabeledContent("Latitude",value:coordinate(station.latitude));LabeledContent("Longitude",value:coordinate(station.longitude));LabeledContent("Altitude",value:text(station.altitudeMetres,suffix:" m",decimals:0))}
  Section("System"){LabeledContent("Software",value:station.softwareVersion ?? "Not reported");LabeledContent("CPU",value:text(station.cpuLoadPercent,suffix:"%",decimals:1));LabeledContent("Memory",value:memory);LabeledContent("Temperature",value:text(station.cpuTemperatureC,suffix:" °C",decimals:1))}
  Section("Time"){LabeledContent("NTP offset",value:text(station.ntpOffsetMS,suffix:" ms",decimals:1));LabeledContent("NTP correction",value:text(station.ntpCorrectionPPM,suffix:" ppm",decimals:1))}
  Section("Radio"){LabeledContent("Frequency correction",value:text(station.frequencyCorrectionKHz,suffix:" kHz",decimals:1));LabeledContent("RF correction",value:text(station.rfCorrectionPPM,suffix:" ppm",decimals:1));LabeledContent("Signal quality",value:text(station.signalQualityDB,suffix:" dB",decimals:1))}
 }.navigationTitle(station.name).navigationBarTitleDisplayMode(.inline)}
 private var memory:String{guard let u=station.ramUsedMB,let t=station.ramTotalMB else{return "Not reported"};return String(format:"%.0f / %.0f MB",u,t)}
 private func coordinate(_ v:Double?)->String{guard let v else{return "Not reported"};return String(format:"%.5f°",v)}
 private func text(_ v:Double?,suffix:String,decimals:Int)->String{guard let v else{return "Not reported"};return String(format:"%.*f%@",decimals,v,suffix)}
 private func relative(_ d:Date?)->String{guard let d else{return "Not reported"};return d.formatted(.relative(presentation:.named))}
}
