package uk.co.rhine59.atommonitor

import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.FileProvider
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private const val DEFAULT_SERVER = "https://granvillehouse.synology.me:8445/"

data class Station(val id:String,val name:String,val latitude:Double?,val longitude:Double?,val altitudeMetres:Double?,val health:String,val lastPosition:Instant?,val lastHeartbeat:Instant?,val lastTechnicalStatus:Instant?,val pilotAwareVersion:String?,val softwareVersion:String?,val cpuLoadPercent:Double?,val ramUsedMB:Double?,val ramTotalMB:Double?,val cpuTemperatureC:Double?,val ntpOffsetMS:Double?,val ntpCorrectionPPM:Double?,val frequencyCorrectionKHz:Double?,val rfCorrectionPPM:Double?,val signalQualityDB:Double?,val voltageV:Double?,val uptimeMinutes:Int?,val lastSeen:Instant?)

private fun JSONArray.stations():List<Station>=(0 until length()).map{i->val o=getJSONObject(i);fun d(k:String)=if(o.isNull(k))null else o.optDouble(k);fun s(k:String)=if(o.isNull(k))null else o.optString(k).takeIf{it.isNotBlank()};fun t(k:String)=s(k)?.let{runCatching{Instant.parse(it)}.getOrNull()};Station(o.getString("id"),o.optString("name",o.getString("id")),d("latitude"),d("longitude"),d("altitudeMetres"),o.optString("health","unknown"),t("lastPosition"),t("lastHeartbeat"),t("lastTechnicalStatus"),s("pilotAwareVersion"),s("softwareVersion"),d("cpuLoadPercent"),d("ramUsedMB"),d("ramTotalMB"),d("cpuTemperatureC"),d("ntpOffsetMS"),d("ntpCorrectionPPM"),d("frequencyCorrectionKHz"),d("rfCorrectionPPM"),d("signalQualityDB"),d("voltageV"),if(o.isNull("uptimeMinutes"))null else o.optInt("uptimeMinutes"),t("lastSeen"))}

class StationVM(app:Application):AndroidViewModel(app){
 private val prefs=app.getSharedPreferences("atom",Context.MODE_PRIVATE);var stations by mutableStateOf<List<Station>>(emptyList());private set;var error by mutableStateOf<String?>(null);private set;var refreshing by mutableStateOf(false);private set;var lastUpdated by mutableStateOf<Instant?>(null);private set;var selectedHealth by mutableStateOf<Set<String>>(emptySet());private set;var selectedVersions by mutableStateOf<Set<String>>(emptySet());private set
 var server:String get()=prefs.getString("server",DEFAULT_SERVER)?:DEFAULT_SERVER;set(v){prefs.edit().putString("server",v).apply()};var refreshMinutes:Int get()=prefs.getInt("refresh",5);set(v){prefs.edit().putInt("refresh",v).apply()};var home:String get()=prefs.getString("home","")?:"";set(v){prefs.edit().putString("home",v).apply()};var inactiveAfterDays:Int get()=prefs.getInt("inactiveDays",2).coerceIn(1,30);set(v){prefs.edit().putInt("inactiveDays",v.coerceIn(1,30)).apply()}
 fun displayHealth(s:Station,now:Instant=Instant.now()):String{val seen=s.lastSeen?:return s.health;return if(Duration.between(seen,now).toDays()>=inactiveAfterDays)"inactive" else s.health}
 fun favourites()=prefs.getStringSet("favourites",emptySet())?:emptySet();fun toggleFavourite(id:String){val x=favourites().toMutableSet();if(!x.add(id))x.remove(id);prefs.edit().putStringSet("favourites",x).apply()}
 val availableHealth get()=stations.map{displayHealth(it)}.distinct().sortedBy{healthOrder(it)};val availableVersions get()=stations.mapNotNull{it.pilotAwareVersion?.trim()?.takeIf(String::isNotEmpty)}.distinct().sorted();val hasFilters get()=selectedHealth.isNotEmpty()||selectedVersions.isNotEmpty()
 fun toggleHealth(v:String){selectedHealth=selectedHealth.toMutableSet().apply{if(!add(v))remove(v)}};fun toggleVersion(v:String){selectedVersions=selectedVersions.toMutableSet().apply{if(!add(v))remove(v)}};fun clearFilters(){selectedHealth=emptySet();selectedVersions=emptySet()};fun thresholdChanged(){selectedHealth=selectedHealth.intersect(availableHealth.toSet())}
 fun filtered(source:List<Station>=stations,query:String="")=source.filter{s->(query.isBlank()||s.name.contains(query,true))&&(selectedHealth.isEmpty()||displayHealth(s) in selectedHealth)&&(selectedVersions.isEmpty()||(s.pilotAwareVersion?.let{it in selectedVersions}==true))}
 private val cache=File(app.cacheDir,"atom-stations-cache.json");init{runCatching{stations=JSONArray(cache.readText()).stations()};refresh();viewModelScope.launch{while(true){delay(refreshMinutes.coerceIn(1,10)*60_000L);refresh()}}}
 fun refresh(){if(refreshing)return;viewModelScope.launch{refreshing=true;runCatching{val base=server.trim().let{if(it.endsWith('/'))it else "$it/"};val c=URI(base+"api/v1/stations").toURL().openConnection() as HttpURLConnection;c.connectTimeout=10000;c.readTimeout=12000;if(c.responseCode !in 200..299)error("HTTP ${c.responseCode}");val text=c.inputStream.bufferedReader().use{it.readText()};stations=JSONArray(text).stations();selectedHealth=selectedHealth.intersect(availableHealth.toSet());selectedVersions=selectedVersions.intersect(availableVersions.toSet());cache.writeText(text);lastUpdated=Instant.now();error=null}.onFailure{error=it.message?:"No Network"};refreshing=false}}
}

class MainActivity:ComponentActivity(){override fun onCreate(s:Bundle?){super.onCreate(s);Configuration.getInstance().userAgentValue=packageName;setContent{MaterialTheme{App()}}}}
enum class Tab(val title:String){Map("Map"),Stations("Stations"),Favourites("Favourites"),Report("Report"),Settings("Settings"),Help("Help")}

@Composable fun App(vm:StationVM=viewModel()){var tab by remember{mutableStateOf(Tab.Map)};var detail by remember{mutableStateOf<Station?>(null)};Scaffold(bottomBar={NavigationBar{Tab.entries.forEach{t->NavigationBarItem(tab==t,{tab=t},{Icon(when(t){Tab.Map->Icons.Default.Map;Tab.Stations->Icons.Default.List;Tab.Favourites->Icons.Default.Star;Tab.Report->Icons.Default.Assessment;Tab.Settings->Icons.Default.Settings;Tab.Help->Icons.Default.Help},null)},{Text(t.title)})}}}){p->Box(Modifier.padding(p)){when(tab){Tab.Map->MapScreen(vm){detail=it};Tab.Stations->StationList(vm.stations,vm){detail=it};Tab.Favourites->StationList(vm.stations.filter{vm.favourites().contains(it.id)},vm){detail=it};Tab.Report->ReportScreen(vm);Tab.Settings->Settings(vm);Tab.Help->Help()}}};detail?.let{s->ModalBottomSheet({detail=null}){Detail(s,vm.displayHealth(s),vm.favourites().contains(s.id)){vm.toggleFavourite(s.id)}}}}

@Composable fun FilterButton(vm:StationVM){var open by remember{mutableStateOf(false)};IconButton({open=true}){Icon(Icons.Default.FilterAlt,"Filter")};if(open)AlertDialog({open=false},{TextButton({open=false}){Text("Done")}},{TextButton(vm::clearFilters){Text("Clear")}},title={Text("Filter stations")},text={LazyColumn{item{Text("Status")};items(vm.availableHealth){v->FilterRow(healthTitle(v),v in vm.selectedHealth){vm.toggleHealth(v)}};item{Text("PilotAware version")};items(vm.availableVersions){v->FilterRow(v,v in vm.selectedVersions){vm.toggleVersion(v)}}}})}
@Composable fun FilterRow(label:String,checked:Boolean,toggle:()->Unit){Row(Modifier.fillMaxWidth().clickable(onClick=toggle),verticalAlignment=androidx.compose.ui.Alignment.CenterVertically){Checkbox(checked,{toggle()});Text(label)}}

@Composable fun MapScreen(vm:StationVM,onStation:(Station)->Unit){var q by remember{mutableStateOf("")};Column{Row(Modifier.padding(12.dp)){Text("Stations",style=MaterialTheme.typography.titleLarge,modifier=Modifier.weight(1f));FilterButton(vm);IconButton(vm::refresh){Icon(Icons.Default.Refresh,null)}};Text(if(vm.error!=null)"No Network • ${vm.stations.size} stations" else "Last updated: ${fmtTime(vm.lastUpdated)} • ${vm.stations.size} stations",modifier=Modifier.padding(horizontal=12.dp),color=if(vm.error!=null)Color.Red else LocalContentColor.current);OutlinedTextField(q,{q=it},label={Text("Find")},modifier=Modifier.fillMaxWidth().padding(12.dp));val shown=vm.filtered(query=q);AndroidView(factory={ctx->MapView(ctx).apply{setTileSource(TileSourceFactory.MAPNIK);setMultiTouchControls(true);controller.setZoom(6.0);controller.setCenter(GeoPoint(54.5,-3.0))}},update={map->map.overlays.removeAll{it is Marker};shown.forEach{s->if(s.latitude!=null&&s.longitude!=null)map.overlays.add(Marker(map).apply{position=GeoPoint(s.latitude,s.longitude);title=s.name;snippet="${healthTitle(vm.displayHealth(s))} • ${s.pilotAwareVersion?:"Version not reported"}";icon=setMarkerIcon(context,vm.displayHealth(s));setOnMarkerClickListener{_,_->onStation(s);true}}};map.invalidate()},modifier=Modifier.fillMaxSize())}}

@Composable fun StationList(list:List<Station>,vm:StationVM,onStation:(Station)->Unit){var q by remember{mutableStateOf("")};Column{Row(Modifier.padding(12.dp)){OutlinedTextField(q,{q=it},label={Text("Find")},modifier=Modifier.weight(1f));FilterButton(vm)};LazyColumn{items(vm.filtered(list,q),key={it.id}){s->ListItem({Text(s.name)},supportingContent={Text("${healthTitle(vm.displayHealth(s))} • ${s.pilotAwareVersion?:"Version not reported"}")},modifier=Modifier.clickable{onStation(s)});HorizontalDivider()}}}}

@Composable fun ReportScreen(vm:StationVM){
 val context=LocalContext.current
 val statuses=listOf("healthy","warning","noRecentHeartbeat","inactive","unknown").map{it to vm.stations.count{s->vm.displayHealth(s)==it}}
 val versions=vm.stations.groupingBy{it.pilotAwareVersion?.trim()?.takeIf(String::isNotEmpty)?:"Not reported"}.eachCount().toList().sortedWith(compareByDescending<Pair<String,Int>>{it.first!="Not reported"}.thenByDescending{it.first})
 LazyColumn(Modifier.padding(16.dp)){
  item{Text("Report",style=MaterialTheme.typography.headlineSmall);Spacer(Modifier.height(12.dp));ReportRow("Total stations",vm.stations.size);Text("Status",style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=18.dp))}
  items(statuses){(name,count)->ReportRow(healthTitle(name),count)}
  item{Text("PilotAware versions",style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=18.dp))}
  items(versions){(version,count)->ReportRow(version,count)}
  item{Button(onClick={shareReport(context,vm)},enabled=vm.stations.isNotEmpty(),modifier=Modifier.padding(top=20.dp)){Icon(Icons.Default.Share,null);Spacer(Modifier.width(8.dp));Text("Share report")};Text("Creates a formatted HTML report with responsive bar graphs plus a CSV station-data attachment and opens the standard Android share chooser.",style=MaterialTheme.typography.bodySmall,modifier=Modifier.padding(top=8.dp))}
 }
}

@Composable private fun ReportRow(label:String,count:Int){Row(Modifier.fillMaxWidth().padding(vertical=5.dp)){Text(label,Modifier.weight(1f));Text(count.toString())}}

private fun shareReport(context:Context,vm:StationVM){
 runCatching{
  val dir=File(context.cacheDir,"reports").apply{mkdirs()};val stamp=DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneId.systemDefault()).format(Instant.now());val html=File(dir,"ATOM-Monitor-Report-$stamp.html");val csv=File(dir,"ATOM-Monitor-Stations-$stamp.csv")
  val statuses=listOf("healthy","warning","noRecentHeartbeat","inactive","unknown").map{healthTitle(it) to vm.stations.count{s->vm.displayHealth(s)==it}};val versions=vm.stations.groupingBy{it.pilotAwareVersion?.trim()?.takeIf(String::isNotEmpty)?:"Not reported"}.eachCount().toList().sortedByDescending{it.first}
  fun bars(rows:List<Pair<String,Int>>):String=rows.joinToString(""){(label,count)->val pct=if(vm.stations.isEmpty())0.0 else count*100.0/vm.stations.size;"<div class='row'><span>${htmlEscape(label)}</span><div class='track'><div class='bar' style='width:${"%.2f".format(java.util.Locale.US,pct)}%'></div></div><b>$count</b></div>"}
  fun table(rows:List<Pair<String,Int>>)=rows.joinToString(""){(label,count)->"<tr><td>${htmlEscape(label)}</td><td class='n'>$count</td></tr>"}
  html.writeText("""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{font-family:sans-serif;background:#f3f5f7;padding:20px;color:#17202a}.card{max-width:720px;margin:auto;background:white;padding:22px;border-radius:16px}h1{margin-bottom:4px}.total{font-size:38px;font-weight:700}.row{display:grid;grid-template-columns:minmax(100px,1.3fr) minmax(100px,3fr) 40px;gap:8px;align-items:center;margin:8px 0}.track{height:18px;background:#e8edf3;border-radius:9px;overflow:hidden}.bar{height:100%;background:#3b82f6;border-radius:9px}table{width:100%;border-collapse:collapse}td{padding:8px;border-bottom:1px solid #eee}.n{text-align:right;font-weight:bold}.foot{margin-top:24px;color:#64748b;font-size:12px}</style></head><body><div class="card"><h1>ATOM Monitor Report</h1><div>Generated ${htmlEscape(absolute(Instant.now()))}</div><div class="total">${vm.stations.size}</div><div>ground stations in the current dataset</div><h2>Status</h2>${bars(statuses)}<table>${table(statuses)}</table><h2>PilotAware versions</h2>${bars(versions)}<table>${table(versions)}</table><div class="foot">ATOM Monitor reports PilotAware ATOM ground-station operational health only. It does not display or record aircraft movements.</div></div></body></html>""")
  csv.writeText(buildString{append("Station,Status,PilotAware Version,Last Seen,Last Heartbeat,Last Position,Last Technical Status,Latitude,Longitude\r\n");vm.stations.sortedBy{it.name.lowercase()}.forEach{s->append(listOf(s.name,healthTitle(vm.displayHealth(s)),s.pilotAwareVersion?:"Not reported",iso(s.lastSeen),iso(s.lastHeartbeat),iso(s.lastPosition),iso(s.lastTechnicalStatus),s.latitude?.toString()?:"",s.longitude?.toString()?:"").joinToString(","){csvEscape(it)}).append("\r\n")}})
  val uris=arrayListOf(FileProvider.getUriForFile(context,"${context.packageName}.fileprovider",html),FileProvider.getUriForFile(context,"${context.packageName}.fileprovider",csv));val intent=Intent(Intent.ACTION_SEND_MULTIPLE).apply{type="*/*";putParcelableArrayListExtra(Intent.EXTRA_STREAM,uris);addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);putExtra(Intent.EXTRA_SUBJECT,"ATOM Monitor station report")};context.startActivity(Intent.createChooser(intent,"Share ATOM Monitor report"))
 }
}

@Composable fun Detail(s:Station,health:String,favourite:Boolean,toggle:()->Unit){LazyColumn(Modifier.padding(16.dp)){item{Row{Text(s.name,style=MaterialTheme.typography.headlineSmall,modifier=Modifier.weight(1f));IconButton(toggle){Icon(if(favourite)Icons.Default.Star else Icons.Default.StarBorder,null)}}};item{Section("Health",listOf("Status" to healthTitle(health),"Record date & time" to absolute(s.lastSeen),"Last heartbeat" to relative(s.lastHeartbeat),"Last seen" to relative(s.lastSeen)))};item{Section("Station",listOf("Station ID" to s.id,"PilotAware version" to n(s.pilotAwareVersion),"Receiver software" to n(s.softwareVersion)))}}}
@Composable fun Section(title:String,rows:List<Pair<String,String>>){Text(title,style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=14.dp));rows.forEach{(a,b)->Row(Modifier.fillMaxWidth().padding(vertical=4.dp)){Text(a,Modifier.weight(1f));Text(b)}}}
@Composable fun Settings(vm:StationVM){var server by remember{mutableStateOf(vm.server)};var refresh by remember{mutableIntStateOf(vm.refreshMinutes)};var inactive by remember{mutableIntStateOf(vm.inactiveAfterDays)};Column(Modifier.padding(16.dp)){Text("Settings",style=MaterialTheme.typography.headlineSmall);OutlinedTextField(server,{server=it},label={Text("Server")});Button({vm.server=server;vm.refresh()}){Text("Save & Test")};Text("Refresh interval: $refresh min");Slider(refresh.toFloat(),{refresh=it.toInt().coerceIn(1,10);vm.refreshMinutes=refresh},valueRange=1f..10f,steps=8);Text("Inactive after: $inactive day${if(inactive==1)"" else "s"}");Slider(inactive.toFloat(),{inactive=it.toInt().coerceIn(1,30);vm.inactiveAfterDays=inactive;vm.thresholdChanged()},valueRange=1f..30f,steps=28);Text("Stations not seen for this many days are shown Inactive. Default 2 days.",style=MaterialTheme.typography.bodySmall)}}
@Composable fun Help(){LazyColumn(Modifier.padding(16.dp)){item{Text("User Guide",style=MaterialTheme.typography.headlineSmall)};item{Text("ATOM Monitor reports PilotAware ATOM ground-station operational health only. It does not display or record aircraft movements. Map and Stations share Status and PilotAware version filters. Inactive after defaults to 2 days. Report summarises status and PilotAware versions and shares formatted HTML with bar graphs plus CSV station data.")}}}

private fun setMarkerIcon(context:Context,health:String)=androidx.core.content.ContextCompat.getDrawable(context,when(health){"inactive","noRecentHeartbeat"->android.R.drawable.presence_busy;"healthy"->android.R.drawable.presence_online;"warning"->android.R.drawable.presence_away;else->android.R.drawable.presence_invisible})
private fun healthOrder(v:String)=when(v){"healthy"->0;"warning"->1;"noRecentHeartbeat"->2;"inactive"->3;else->4}
private fun healthTitle(v:String)=when(v){"healthy"->"Healthy";"warning"->"Warning";"noRecentHeartbeat"->"No recent heartbeat";"inactive"->"Inactive";else->"Unknown"}
private fun n(v:String?)=v?:"Not reported"
private fun absolute(v:Instant?)=v?.atZone(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm:ss"))?:"Not reported"
private fun fmtTime(v:Instant?)=v?.atZone(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("HH:mm"))?:"Not yet"
private fun relative(v:Instant?):String{if(v==null)return"Not reported";val s=(Instant.now().epochSecond-v.epochSecond).coerceAtLeast(0);return if(s<3600)"${s/60} min ago" else if(s<86400)"${s/3600} h ago" else "${s/86400} d ago"}
private fun iso(v:Instant?)=v?.toString()?:"Not reported"
private fun csvEscape(v:String)="\"${v.replace("\"","\"\"")}\""
private fun htmlEscape(v:String)=v.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;")
