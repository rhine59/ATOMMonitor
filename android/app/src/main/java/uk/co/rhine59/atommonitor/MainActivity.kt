package uk.co.rhine59.atommonitor

import android.app.Application
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
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
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private const val DEFAULT_SERVER = "https://granvillehouse.synology.me:8445/"

data class Station(
    val id:String,val name:String,val latitude:Double?,val longitude:Double?,val altitudeMetres:Double?,
    val health:String,val lastPosition:Instant?,val lastHeartbeat:Instant?,val lastTechnicalStatus:Instant?,
    val pilotAwareVersion:String?,val softwareVersion:String?,val cpuLoadPercent:Double?,val ramUsedMB:Double?,
    val ramTotalMB:Double?,val cpuTemperatureC:Double?,val ntpOffsetMS:Double?,val ntpCorrectionPPM:Double?,
    val frequencyCorrectionKHz:Double?,val rfCorrectionPPM:Double?,val signalQualityDB:Double?,val voltageV:Double?,
    val uptimeMinutes:Int?,val lastSeen:Instant?
)

private fun JSONArray.stations():List<Station> = (0 until length()).map { i ->
    val o=getJSONObject(i)
    fun d(k:String)=if(o.isNull(k)) null else o.optDouble(k)
    fun s(k:String)=if(o.isNull(k)) null else o.optString(k).takeIf{it.isNotBlank()}
    fun t(k:String)=s(k)?.let{runCatching{Instant.parse(it)}.getOrNull()}
    Station(o.getString("id"),o.optString("name",o.getString("id")),d("latitude"),d("longitude"),d("altitudeMetres"),
        o.optString("health","unknown"),t("lastPosition"),t("lastHeartbeat"),t("lastTechnicalStatus"),s("pilotAwareVersion"),
        s("softwareVersion"),d("cpuLoadPercent"),d("ramUsedMB"),d("ramTotalMB"),d("cpuTemperatureC"),d("ntpOffsetMS"),
        d("ntpCorrectionPPM"),d("frequencyCorrectionKHz"),d("rfCorrectionPPM"),d("signalQualityDB"),d("voltageV"),
        if(o.isNull("uptimeMinutes")) null else o.optInt("uptimeMinutes"),t("lastSeen"))
}

class StationVM(app:Application):AndroidViewModel(app){
    private val prefs=app.getSharedPreferences("atom",Context.MODE_PRIVATE)
    var stations by mutableStateOf<List<Station>>(emptyList()); private set
    var error by mutableStateOf<String?>(null); private set
    var refreshing by mutableStateOf(false); private set
    var lastUpdated by mutableStateOf<Instant?>(null); private set
    var server:String get()=prefs.getString("server",DEFAULT_SERVER)?:DEFAULT_SERVER; set(v){prefs.edit().putString("server",v).apply()}
    var refreshMinutes:Int get()=prefs.getInt("refresh",5); set(v){prefs.edit().putInt("refresh",v).apply()}
    var home:String get()=prefs.getString("home","")?:""; set(v){prefs.edit().putString("home",v).apply()}
    fun favourites()=prefs.getStringSet("favourites",emptySet())?:emptySet()
    fun toggleFavourite(id:String){val x=favourites().toMutableSet();if(!x.add(id))x.remove(id);prefs.edit().putStringSet("favourites",x).apply()}
    private val cache=File(app.cacheDir,"atom-stations-cache.json")
    init { loadCache(); refresh(); autoRefresh() }
    private fun loadCache(){runCatching{stations=JSONArray(cache.readText()).stations()}}
    fun refresh(){if(refreshing)return;viewModelScope.launch{refreshing=true;runCatching{
        val base=server.trim().let{if(it.endsWith('/'))it else "$it/"};val c=URI(base+"api/v1/stations").toURL().openConnection() as HttpURLConnection
        c.connectTimeout=10000;c.readTimeout=12000;c.requestMethod="GET";if(c.responseCode !in 200..299)error("HTTP ${c.responseCode}")
        val text=c.inputStream.bufferedReader().use{it.readText()};val result=JSONArray(text).stations();stations=result;cache.writeText(text);lastUpdated=Instant.now();error=null
    }.onFailure{error=it.message?:"No Network"};refreshing=false}}
    private fun autoRefresh(){viewModelScope.launch{while(true){delay(refreshMinutes.coerceIn(1,10)*60_000L);refresh()}}}
}

class MainActivity:ComponentActivity(){override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);Configuration.getInstance().userAgentValue=packageName;setContent{MaterialTheme{App()}}}}

enum class Tab(val title:String){Map("Map"),Stations("Stations"),Favourites("Favourites"),Settings("Settings"),Help("Help")}

@Composable fun App(vm:StationVM= viewModel()){
    var tab by remember{mutableStateOf(Tab.Map)};var detail by remember{mutableStateOf<Station?>(null)}
    Scaffold(bottomBar={NavigationBar{Tab.entries.forEach{t->NavigationBarItem(selected=tab==t,onClick={tab=t},icon={Icon(when(t){Tab.Map->Icons.Default.Map;Tab.Stations->Icons.Default.List;Tab.Favourites->Icons.Default.Star;Tab.Settings->Icons.Default.Settings;Tab.Help->Icons.Default.Help},null)},label={Text(t.title)})}}}){p->
        Box(Modifier.padding(p)){when(tab){Tab.Map->MapScreen(vm){detail=it};Tab.Stations->StationList(vm.stations,vm){detail=it};Tab.Favourites->StationList(vm.stations.filter{vm.favourites().contains(it.id)},vm){detail=it};Tab.Settings->Settings(vm);Tab.Help->Help()}}
    }
    detail?.let{s->ModalBottomSheet(onDismissRequest={detail=null}){Detail(s,vm.favourites().contains(s.id)){vm.toggleFavourite(s.id)}}}
}

@Composable fun MapScreen(vm:StationVM,onStation:(Station)->Unit){
    var query by remember{mutableStateOf("")};Column(Modifier.fillMaxSize()){
        Row(Modifier.padding(12.dp),horizontalArrangement=Arrangement.spacedBy(8.dp)){Text("ATOM Stations",style=MaterialTheme.typography.titleLarge,modifier=Modifier.weight(1f));IconButton(onClick=vm::refresh){Icon(Icons.Default.Refresh,"Refresh")}}
        Text(if(vm.error!=null)"No Network" else "Last updated: ${fmtTime(vm.lastUpdated)}",color=if(vm.error!=null)Color.Red else LocalContentColor.current,modifier=Modifier.padding(horizontal=12.dp))
        OutlinedTextField(query,{query=it},label={Text("Find")},singleLine=true,modifier=Modifier.fillMaxWidth().padding(12.dp))
        val shown=vm.stations.filter{query.isBlank()||it.name.contains(query,true)}
        AndroidView(factory={ctx->MapView(ctx).apply{setTileSource(TileSourceFactory.MAPNIK);setMultiTouchControls(true);controller.setZoom(6.0);controller.setCenter(GeoPoint(54.5,-3.0))}},update={map->map.overlays.removeAll{it is Marker};shown.forEach{s->if(s.latitude!=null&&s.longitude!=null){map.overlays.add(Marker(map).apply{position=GeoPoint(s.latitude,s.longitude);title=s.name;snippet=healthTitle(s.health);setOnMarkerClickListener{_,_->onStation(s);true}})}};map.invalidate()},modifier=Modifier.fillMaxSize())
    }
}

@Composable fun StationList(list:List<Station>,vm:StationVM,onStation:(Station)->Unit){var q by remember{mutableStateOf("")};Column{Row(Modifier.padding(12.dp)){OutlinedTextField(q,{q=it},label={Text("Find")},modifier=Modifier.weight(1f));IconButton(onClick=vm::refresh){Icon(Icons.Default.Refresh,null)}};LazyColumn{items(list.filter{q.isBlank()||it.name.contains(q,true)},key={it.id}){s->ListItem(headlineContent={Text(s.name)},supportingContent={Text("${healthTitle(s.health)} • ${relative(s.lastHeartbeat)}")},modifier=Modifier.fillMaxWidth());HorizontalDivider();TextButton(onClick={onStation(s)},modifier=Modifier.fillMaxWidth()){Text("View details")}}}}}

@Composable fun Detail(s:Station,favourite:Boolean,toggle:()->Unit){LazyColumn(Modifier.fillMaxWidth().padding(16.dp)){item{Row{Text(s.name,style=MaterialTheme.typography.headlineSmall,modifier=Modifier.weight(1f));IconButton(onClick=toggle){Icon(if(favourite)Icons.Default.Star else Icons.Default.StarBorder,null)}}};item{Section("Health",listOf("Status" to healthTitle(s.health),"Record date & time" to absolute(s.lastSeen),"Last heartbeat" to relative(s.lastHeartbeat),"Last seen" to relative(s.lastSeen),"Last position" to relative(s.lastPosition),"Last technical status" to relative(s.lastTechnicalStatus)))};item{Section("Station",listOf("Station ID" to s.id,"PilotAware version" to n(s.pilotAwareVersion),"Receiver software" to n(s.softwareVersion),"Uptime" to uptime(s.uptimeMinutes),"Supply voltage" to num(s.voltageV," V",2)))};item{Section("Location",listOf("Latitude" to num(s.latitude,"°",5),"Longitude" to num(s.longitude,"°",5),"Altitude" to num(s.altitudeMetres," m",0)))};item{Section("System",listOf("CPU load" to num(s.cpuLoadPercent,"%",1),"Memory" to if(s.ramUsedMB!=null&&s.ramTotalMB!=null)"%.0f / %.0f MB".format(s.ramUsedMB,s.ramTotalMB) else "Not reported","CPU temperature" to num(s.cpuTemperatureC," °C",1)))};item{Section("Time",listOf("NTP offset" to num(s.ntpOffsetMS," ms",1),"NTP correction" to num(s.ntpCorrectionPPM," ppm",1)))};item{Section("Radio",listOf("Frequency correction" to num(s.frequencyCorrectionKHz," kHz",1),"RF correction" to num(s.rfCorrectionPPM," ppm",1),"Signal quality" to num(s.signalQualityDB," dB",1)))}}
}

@Composable fun Section(title:String,rows:List<Pair<String,String>>){Text(title,style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=14.dp,bottom=4.dp));rows.forEach{(a,b)->Row(Modifier.fillMaxWidth().padding(vertical=4.dp)){Text(a,Modifier.weight(1f));Text(b)}}}

@Composable fun Settings(vm:StationVM){var server by remember{mutableStateOf(vm.server)};var refresh by remember{mutableIntStateOf(vm.refreshMinutes)};Column(Modifier.padding(16.dp)){Text("Settings",style=MaterialTheme.typography.headlineSmall);OutlinedTextField(server,{server=it},label={Text("Server")},modifier=Modifier.fillMaxWidth());Button(onClick={vm.server=server;vm.refresh()}){Text("Save & Test")};Spacer(Modifier.height(20.dp));Text("Refresh interval: $refresh min");Slider(refresh.toFloat(),{refresh=it.toInt().coerceIn(1,10);vm.refreshMinutes=refresh},valueRange=1f..10f,steps=8);Text("Home station");var open by remember{mutableStateOf(false)};Button(onClick={open=true}){Text(vm.stations.firstOrNull{it.id==vm.home}?.name?:"Default UK view")};DropdownMenu(open,{open=false}){DropdownMenuItem({Text("Default UK view")},{vm.home="";open=false});vm.stations.filter{it.latitude!=null}.sortedBy{it.name}.forEach{s->DropdownMenuItem({Text(s.name)},{vm.home=s.id;open=false})}}}}

@Composable fun Help(){LazyColumn(Modifier.padding(16.dp)){item{Text("User Guide",style=MaterialTheme.typography.headlineSmall)};item{Section("What ATOM Monitor does",listOf("Purpose" to "Ground-station operational health only","Aircraft data" to "Not displayed or recorded"))};item{Text("Map: browse and find ATOM stations, then tap a marker for detail. Stations and Favourites provide list views. Settings controls the server, refresh interval and Home station. Station detail includes the exact Record date & time plus relative heartbeat/position/technical ages. Cached station data remains available after a connection failure. Normal remote operation uses the public HTTPS ATOM Monitor service.",modifier=Modifier.padding(vertical=12.dp))}}}

private fun healthTitle(v:String)=when(v){"healthy"->"Healthy";"warning"->"Warning";"noRecentHeartbeat"->"No recent heartbeat";else->"Unknown"}
private fun n(v:String?)=v?:"Not reported"
private fun num(v:Double?,suffix:String,d:Int)=v?.let{"%.${d}f%s".format(it,suffix)}?:"Not reported"
private fun absolute(v:Instant?)=v?.atZone(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm:ss"))?:"Not reported"
private fun fmtTime(v:Instant?)=v?.atZone(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("HH:mm"))?:"Not yet"
private fun relative(v:Instant?):String{if(v==null)return "Not reported";val s=(Instant.now().epochSecond-v.epochSecond).coerceAtLeast(0);return when{ s<60->"${s}s ago";s<3600->"${s/60} min ago";s<86400->"${s/3600} h ago";else->"${s/86400} d ago"}}
private fun uptime(v:Int?)=v?.let{if(it>=1440)"${it/1440}d ${(it%1440)/60}h ${it%60}m" else if(it>=60)"${it/60}h ${it%60}m" else "${it}m"}?:"Not reported"
