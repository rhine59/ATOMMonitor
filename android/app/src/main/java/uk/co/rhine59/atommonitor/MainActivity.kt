package uk.co.rhine59.atommonitor

import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.FileProvider
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
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

data class Station(
    val id: String,
    val name: String,
    val latitude: Double?,
    val longitude: Double?,
    val altitudeMetres: Double?,
    val health: String,
    val lastPosition: Instant?,
    val lastHeartbeat: Instant?,
    val lastTechnicalStatus: Instant?,
    val pilotAwareVersion: String?,
    val softwareVersion: String?,
    val cpuLoadPercent: Double?,
    val ramUsedMB: Double?,
    val ramTotalMB: Double?,
    val cpuTemperatureC: Double?,
    val ntpOffsetMS: Double?,
    val ntpCorrectionPPM: Double?,
    val frequencyCorrectionKHz: Double?,
    val rfCorrectionPPM: Double?,
    val signalQualityDB: Double?,
    val voltageV: Double?,
    val uptimeMinutes: Int?,
    val lastSeen: Instant?
)

private fun JSONArray.stations(): List<Station> =
    (0 until length()).map { index ->
        val o = getJSONObject(index)
        fun doubleValue(key: String): Double? =
            if (o.isNull(key)) null else o.optDouble(key)

        fun stringValue(key: String): String? =
            if (o.isNull(key)) null
            else o.optString(key).takeIf { it.isNotBlank() }

        fun instantValue(key: String): Instant? =
            stringValue(key)?.let {
                runCatching { Instant.parse(it) }.getOrNull()
            }

        Station(
            id = o.getString("id"),
            name = o.optString("name", o.getString("id")),
            latitude = doubleValue("latitude"),
            longitude = doubleValue("longitude"),
            altitudeMetres = doubleValue("altitudeMetres"),
            health = o.optString("health", "unknown"),
            lastPosition = instantValue("lastPosition"),
            lastHeartbeat = instantValue("lastHeartbeat"),
            lastTechnicalStatus = instantValue("lastTechnicalStatus"),
            pilotAwareVersion = stringValue("pilotAwareVersion"),
            softwareVersion = stringValue("softwareVersion"),
            cpuLoadPercent = doubleValue("cpuLoadPercent"),
            ramUsedMB = doubleValue("ramUsedMB"),
            ramTotalMB = doubleValue("ramTotalMB"),
            cpuTemperatureC = doubleValue("cpuTemperatureC"),
            ntpOffsetMS = doubleValue("ntpOffsetMS"),
            ntpCorrectionPPM = doubleValue("ntpCorrectionPPM"),
            frequencyCorrectionKHz = doubleValue("frequencyCorrectionKHz"),
            rfCorrectionPPM = doubleValue("rfCorrectionPPM"),
            signalQualityDB = doubleValue("signalQualityDB"),
            voltageV = doubleValue("voltageV"),
            uptimeMinutes =
                if (o.isNull("uptimeMinutes")) null
                else o.optInt("uptimeMinutes"),
            lastSeen = instantValue("lastSeen")
        )
    }

class StationVM(app: Application) : AndroidViewModel(app) {
    private val prefs =
        app.getSharedPreferences("atom", Context.MODE_PRIVATE)

    var stations by mutableStateOf<List<Station>>(emptyList())
        private set
    var error by mutableStateOf<String?>(null)
        private set
    var refreshing by mutableStateOf(false)
        private set
    var lastUpdated by mutableStateOf<Instant?>(null)
        private set
    var selectedHealth by mutableStateOf<Set<String>>(emptySet())
        private set
    var selectedVersions by mutableStateOf<Set<String>>(emptySet())
        private set
    var filterVersionNotReported by mutableStateOf(false)
        private set
    var stationSearch by mutableStateOf("")

    var server: String
        get() = prefs.getString("server", DEFAULT_SERVER) ?: DEFAULT_SERVER
        set(value) { prefs.edit().putString("server", value).apply() }

    var refreshMinutes: Int
        get() = prefs.getInt("refresh", 5)
        set(value) { prefs.edit().putInt("refresh", value).apply() }

    var home: String
        get() = prefs.getString("home", "") ?: ""
        set(value) { prefs.edit().putString("home", value).apply() }

    var highlightBackLevelSoftware: Boolean
        get() = prefs.getBoolean("highlightBackLevelSoftware", false)
        set(value) { prefs.edit().putBoolean("highlightBackLevelSoftware", value).apply() }

    var inactiveAfterDays: Int
        get() = prefs.getInt("inactiveDays", 2).coerceIn(1, 30)
        set(value) {
            prefs.edit().putInt(
                "inactiveDays",
                value.coerceIn(1, 30)
            ).apply()
        }

    fun displayHealth(
        station: Station,
        now: Instant = Instant.now()
    ): String {
        val seen = station.lastSeen ?: return station.health
        return if (
            Duration.between(seen, now).toDays() >= inactiveAfterDays
        ) "inactive" else station.health
    }

    fun favourites(): Set<String> =
        prefs.getStringSet("favourites", emptySet()) ?: emptySet()

    fun toggleFavourite(id: String) {
        val values = favourites().toMutableSet()
        if (!values.add(id)) values.remove(id)
        prefs.edit().putStringSet("favourites", values).apply()
    }

    val availableHealth: List<String>
        get() = stations
            .map { displayHealth(it) }
            .distinct()
            .sortedBy { healthOrder(it) }

    val availableVersions: List<String>
        get() = stations
            .mapNotNull {
                it.pilotAwareVersion?.trim()
                    ?.takeIf(String::isNotEmpty)
            }
            .distinct()
            .sorted()

    val hasFilters: Boolean
        get() = selectedHealth.isNotEmpty() || selectedVersions.isNotEmpty() || filterVersionNotReported

    fun isBackLevel(station: Station): Boolean {
        if (!highlightBackLevelSoftware || displayHealth(station) != "healthy") return false
        val version = station.pilotAwareVersion
            ?.trim()?.takeIf { it.isNotEmpty() }
            ?: return false

        val newest = stations
            .mapNotNull {
                it.pilotAwareVersion?.trim()
                    ?.takeIf(String::isNotEmpty)
            }
            .maxWithOrNull(::compareVersions)
            ?: return false

        return compareVersions(version, newest) < 0
    }

    fun toggleHealth(value: String) {
        selectedHealth = selectedHealth.toMutableSet().apply {
            if (!add(value)) remove(value)
        }
    }

    fun toggleVersion(value: String) {
        filterVersionNotReported = false
        selectedVersions = selectedVersions.toMutableSet().apply {
            if (!add(value)) remove(value)
        }
    }

    fun clearFilters() {
        selectedHealth = emptySet()
        selectedVersions = emptySet()
        filterVersionNotReported = false
    }

    fun showAllStations() { clearFilters(); stationSearch = "" }
    fun showHealth(value: String) { clearFilters(); stationSearch = ""; selectedHealth = setOf(value) }
    fun showVersion(value: String?) {
        clearFilters(); stationSearch = ""
        if (value == null) filterVersionNotReported = true else selectedVersions = setOf(value)
    }
    fun toggleVersionNotReported() {
        selectedVersions = emptySet()
        filterVersionNotReported = !filterVersionNotReported
    }

    fun thresholdChanged() {
        selectedHealth =
            selectedHealth.intersect(availableHealth.toSet())
    }

    fun filtered(
        source: List<Station> = stations,
        query: String = ""
    ): List<Station> =
        source.filter { station ->
            val matchesQuery =
                query.isBlank() ||
                station.name.contains(query, ignoreCase = true)

            val matchesHealth =
                selectedHealth.isEmpty() ||
                displayHealth(station) in selectedHealth

            val version = station.pilotAwareVersion?.trim()?.takeIf(String::isNotEmpty)
            val matchesVersion = when {
                filterVersionNotReported -> version == null
                selectedVersions.isEmpty() -> true
                else -> version in selectedVersions
            }

            matchesQuery && matchesHealth && matchesVersion
        }

    private val cache =
        File(app.cacheDir, "atom-stations-cache.json")

    init {
        runCatching {
            stations = JSONArray(cache.readText()).stations()
        }

        refresh()

        viewModelScope.launch {
            while (true) {
                delay(refreshMinutes.coerceIn(1, 10) * 60_000L)
                refresh()
            }
        }
    }

    fun refresh() {
        if (refreshing) return

        viewModelScope.launch {
            refreshing = true

            runCatching {
                val response = withContext(Dispatchers.IO) {
                val base = server.trim().let {
                    if (it.endsWith('/')) it else "$it/"
                }

                val connection =
                    URI(base + "api/v1/stations")
                        .toURL()
                        .openConnection() as HttpURLConnection

                connection.connectTimeout = 10_000
                connection.readTimeout = 12_000

                if (connection.responseCode !in 200..299) {
                    error("HTTP ${connection.responseCode}")
                }

                connection.inputStream
                    .bufferedReader()
                    .use { it.readText() }
                }

                stations = JSONArray(response).stations()

                selectedHealth =
                    selectedHealth.intersect(availableHealth.toSet())

                selectedVersions =
                    selectedVersions.intersect(availableVersions.toSet())

                cache.writeText(response)
                lastUpdated = Instant.now()
                error = null
            }.onFailure {
                Log.e("ATOMMonitor", "Station refresh failed", it)
                error = "${it::class.simpleName}: ${it.message ?: "No message"}"
            }
            refreshing = false
        }
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Configuration.getInstance().userAgentValue = packageName

        setContent {
            MaterialTheme {
                App()
            }
        }
    }
}

enum class Tab(val title: String) {
    Map("Map"),
    Stations("Stations"),
    Favourites("Favourites"),
    Report("Report"),
    Admin("Admin"),
    Settings("Settings"),
    Help("Help"),
    Feedback("Feedback"),
    About("About"),
    Legend("Legend"),
    More("More")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun App(vm: StationVM = viewModel()) {
    var tab by remember { mutableStateOf(Tab.Map) }
    var detail by remember { mutableStateOf<Station?>(null) }

    Scaffold(
        bottomBar = {
            Surface(tonalElevation = 3.dp) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val primaryTabs = listOf(Tab.Map, Tab.Stations, Tab.Favourites, Tab.Report, Tab.More)
                    primaryTabs.forEach { item ->
                        val selected = tab == item || (item == Tab.More && tab in listOf(Tab.Admin, Tab.Settings, Tab.Legend, Tab.Help, Tab.Feedback, Tab.About))

                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .clickable { tab = item }
                                .padding(vertical = 6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(
                                imageVector = when (item) {
                                    Tab.Map -> Icons.Default.Map
                                    Tab.Stations -> Icons.Default.List
                                    Tab.Favourites -> Icons.Default.Star
                                    Tab.Report -> Icons.Default.Assessment
                                    Tab.Admin -> Icons.Default.AdminPanelSettings
                                    Tab.Settings -> Icons.Default.Settings
                                    Tab.Help -> Icons.Default.Help
                                    Tab.Feedback -> Icons.Default.Star
                                    Tab.About -> Icons.Default.Info
                                    Tab.Legend -> Icons.Default.Palette
                                    Tab.More -> Icons.Default.MoreHoriz
                                },
                                contentDescription = item.title,
                                modifier = Modifier.size(22.dp),
                                tint = if (selected)
                                    MaterialTheme.colorScheme.primary
                                else
                                    LocalContentColor.current
                            )

                            Text(
                                text = item.title,
                                maxLines = 1,
                                fontSize = 10.sp,
                                color = if (selected)
                                    MaterialTheme.colorScheme.primary
                                else
                                    LocalContentColor.current
                            )
                        }
                    }
                }
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (tab) {
                Tab.Map -> MapScreen(vm) { detail = it }
                Tab.Stations ->
                    StationList(vm.stations, vm) { detail = it }
                Tab.Favourites ->
                    StationList(
                        vm.stations.filter {
                            vm.favourites().contains(it.id)
                        },
                        vm
                    ) { detail = it }
                Tab.Report -> ReportScreen(vm) { tab = Tab.Stations }
                Tab.Admin -> AdminScreen(vm)
                Tab.Settings -> Settings(vm)
                Tab.Help -> Help()
                Tab.Feedback -> FeedbackScreen(vm.server)
                Tab.About -> AboutScreen()
                Tab.Legend -> StationIconLegend(vm)
                Tab.More -> MoreScreen { tab = it }
            }
        }
    }

    detail?.let { station ->
        ModalBottomSheet(
            onDismissRequest = { detail = null }
        ) {
            Detail(
                station,
                vm.displayHealth(station),
                vm.isBackLevel(station),
                vm.favourites().contains(station.id)
            ) {
                vm.toggleFavourite(station.id)
            }
        }
    }
}

@Composable
fun FilterButton(vm: StationVM) {
    var open by remember { mutableStateOf(false) }

    IconButton(onClick = { open = true }) {
        Icon(Icons.Default.FilterAlt, "Filter")
    }

    if (open) {
        AlertDialog(
            onDismissRequest = { open = false },
            confirmButton = {
                TextButton(onClick = { open = false }) {
                    Text("Done")
                }
            },
            dismissButton = {
                TextButton(onClick = vm::clearFilters) {
                    Text("Clear")
                }
            },
            title = { Text("Filter stations") },
            text = {
                LazyColumn {
                    item { Text("Status") }

                    items(vm.availableHealth) { value ->
                        FilterRow(
                            healthTitle(value),
                            value in vm.selectedHealth
                        ) {
                            vm.toggleHealth(value)
                        }
                    }

                    item { Text("PilotAware version") }

                    items(vm.availableVersions) { value ->
                        FilterRow(value, value in vm.selectedVersions) { vm.toggleVersion(value) }
                    }
                    item { FilterRow("Not reported", vm.filterVersionNotReported) { vm.toggleVersionNotReported() } }
                }
            }
        )
    }
}

@Composable
fun FilterRow(
    label: String,
    checked: Boolean,
    toggle: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = toggle),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Checkbox(
            checked = checked,
            onCheckedChange = { toggle() }
        )
        Text(label)
    }
}

@Composable
fun MapScreen(
    vm: StationVM,
    onStation: (Station) -> Unit
) {
    var query by remember { mutableStateOf("") }

    Column {
        Row(Modifier.padding(12.dp)) {
            Text(
                "Stations",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.weight(1f)
            )
            FilterButton(vm)
            IconButton(onClick = vm::refresh) {
                Icon(Icons.Default.Refresh, "Refresh")
            }
        }

        Text(
            text = if (vm.error != null) {
                "No Network • ${vm.stations.size} stations"
            } else {
                "Last updated: ${fmtTime(vm.lastUpdated)} • ${vm.stations.size} stations"
            },
            modifier = Modifier.padding(horizontal = 12.dp),
            color = if (vm.error != null)
                Color.Red
            else
                LocalContentColor.current
        )

        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = { Text("Find") },
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp)
        )

        val shown = vm.filtered(query = query)

        AndroidView(
            factory = { context ->
                MapView(context).apply {
                    setTileSource(TileSourceFactory.MAPNIK)
                    setMultiTouchControls(true)
                    controller.setZoom(6.0)
                    controller.setCenter(GeoPoint(54.5, -3.0))
                }
            },
            update = { map ->
                map.overlays.removeAll { it is Marker }

                shown.forEach { station ->
                    val latitude = station.latitude
                    val longitude = station.longitude

                    if (latitude != null && longitude != null) {
                        map.overlays.add(
                            Marker(map).apply {
                                position = GeoPoint(
                                    latitude,
                                    longitude
                                )
                                title = station.name
                                snippet =
                                    "${healthTitle(vm.displayHealth(station))} • " +
                                    (station.pilotAwareVersion
                                        ?: "Version not reported")
                                icon = setMarkerIcon(
                                    map.context,
                                    vm.displayHealth(station)
                                )
                                setOnMarkerClickListener { _, _ ->
                                    onStation(station)
                                    true
                                }
                            }
                        )
                    }
                }

                map.invalidate()
            },
            modifier = Modifier.fillMaxSize()
        )
    }
}

@Composable
fun StationList(
    list: List<Station>,
    vm: StationVM,
    onStation: (Station) -> Unit
) {
    Column {
        Row(Modifier.padding(12.dp)) {
            OutlinedTextField(
                value = vm.stationSearch,
                onValueChange = { vm.stationSearch = it },
                label = { Text("Find") },
                modifier = Modifier.weight(1f)
            )
            FilterButton(vm)
        }

        LazyColumn {
            items(
                items = vm.filtered(list, vm.stationSearch),
                key = { it.id }
            ) { station ->
                ListItem(
                    headlineContent = {
                        Text(station.name)
                    },
                    supportingContent = {
                        Text(
                            "${healthTitle(vm.displayHealth(station))} • " +
                            (station.pilotAwareVersion
                                ?: "Version not reported")
                        )
                    },
                    modifier = Modifier.clickable {
                        onStation(station)
                    }
                )
                HorizontalDivider()
            }
        }
    }
}

@Composable fun ReportScreen(vm:StationVM,onOpenStations:()->Unit){
 val context=LocalContext.current
 val statuses=listOf("healthy","warning","noRecentHeartbeat","inactive","unknown").map{it to vm.stations.count{s->vm.displayHealth(s)==it}}
 val versions=vm.stations.groupingBy{it.pilotAwareVersion?.trim()?.takeIf(String::isNotEmpty)?:"Not reported"}.eachCount().toList().sortedWith(compareByDescending<Pair<String,Int>>{it.first!="Not reported"}.thenByDescending{it.first})
 LazyColumn(Modifier.padding(16.dp)){
  item{Text("Report",style=MaterialTheme.typography.headlineSmall);Spacer(Modifier.height(12.dp));ReportRow("Total stations",vm.stations.size){vm.showAllStations();onOpenStations()};Text("Status",style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=18.dp))}
  items(statuses){(name,count)->ReportRow(healthTitle(name),count){vm.showHealth(name);onOpenStations()}}
  item{Text("PilotAware versions",style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=18.dp))}
  items(versions){(version,count)->ReportRow(version,count){vm.showVersion(version.takeUnless{it=="Not reported"});onOpenStations()}}
  item{Button(onClick={shareReport(context,vm)},enabled=vm.stations.isNotEmpty(),modifier=Modifier.padding(top=20.dp)){Icon(Icons.Default.Share,null);Spacer(Modifier.width(8.dp));Text("Share report")};Text("Creates a formatted HTML report with responsive bar graphs plus a CSV station-data attachment and opens the standard Android share chooser.",style=MaterialTheme.typography.bodySmall,modifier=Modifier.padding(top=8.dp))}
 }
}

@Composable private fun ReportRow(label:String,count:Int,open:()->Unit){Row(Modifier.fillMaxWidth().clickable(onClick=open).padding(vertical=10.dp),verticalAlignment=Alignment.CenterVertically){Text(label,Modifier.weight(1f));Text(count.toString());Spacer(Modifier.width(8.dp));Icon(Icons.Default.ChevronRight,null,Modifier.size(16.dp))}}

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

@Composable fun Detail(s:Station,health:String,backLevel:Boolean,favourite:Boolean,toggle:()->Unit){
 val context=LocalContext.current
 val iconTitle=if(backLevel&&health=="healthy")"Healthy — back-level software" else healthTitle(health)
 val explanation=if(backLevel&&health=="healthy")"The station is operational, but its reported PilotAware software version is older than the newest version currently seen by ATOM Monitor." else healthExplanation(health)
 LazyColumn(Modifier.padding(16.dp)){
  item{Row(verticalAlignment=Alignment.CenterVertically){Text(s.name,style=MaterialTheme.typography.headlineSmall,modifier=Modifier.weight(1f));IconButton(toggle){Icon(if(favourite)Icons.Default.Star else Icons.Default.StarBorder,null)}}}
  item{Text("Health",style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=14.dp));Row(Modifier.fillMaxWidth().padding(vertical=10.dp),verticalAlignment=Alignment.Top){Icon(healthIcon(health,backLevel),iconTitle,tint=healthColour(health,backLevel),modifier=Modifier.size(42.dp));Spacer(Modifier.width(12.dp));Column{Text(iconTitle,style=MaterialTheme.typography.titleSmall);Text(explanation,style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)}};DetailRows(listOf("Status" to healthTitle(health),"Record date & time" to absolute(s.lastSeen),"Last heartbeat" to relative(s.lastHeartbeat),"Last seen" to relative(s.lastSeen),"Last position" to relative(s.lastPosition),"Last technical status" to relative(s.lastTechnicalStatus)))}
  item{Section("Station",listOf("Station ID" to s.id,"PilotAware version" to n(s.pilotAwareVersion),"Receiver software" to n(s.softwareVersion)))}
  item{Section("Location",listOf("Latitude" to coordinate(s.latitude),"Longitude" to coordinate(s.longitude),"Altitude" to number(s.altitudeMetres," m",0)));if(s.latitude!=null&&s.longitude!=null){TextButton(onClick={val url="https://www.google.com/maps?q=${s.latitude},${s.longitude}&t=k&z=18";context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(url)))},contentPadding=PaddingValues(0.dp)){Icon(Icons.Default.LocationOn,null);Spacer(Modifier.width(6.dp));Text("View satellite location in Google Maps")}}}
  item{Section("System",listOf("CPU load" to number(s.cpuLoadPercent,"%",1),"Memory" to memory(s),"CPU temperature" to number(s.cpuTemperatureC," °C",1)))}
  item{Section("Time",listOf("NTP offset" to number(s.ntpOffsetMS," ms",1),"NTP correction" to number(s.ntpCorrectionPPM," ppm",1)))}
  item{Section("Radio",listOf("RF correction" to number(s.rfCorrectionPPM," ppm",1),"Signal quality" to number(s.signalQualityDB," dB",1)))}
 }
}

@Composable
fun MoreScreen(onSelect: (Tab) -> Unit) {
    val destinations = listOf(
        Triple(Tab.About, Icons.Default.Info, "Version, attribution and licensing"),
        Triple(Tab.Admin, Icons.Default.AdminPanelSettings, "Monitor and scale ATOM services"),
        Triple(Tab.Feedback, Icons.Default.Star, "Send feedback"),
        Triple(Tab.Help, Icons.Default.Help, "User guide"),
        Triple(Tab.Legend, Icons.Default.Palette, "Station icon colours and meanings"),
        Triple(Tab.Settings, Icons.Default.Settings, "Server, refresh and station status preferences")
    )
    LazyColumn(Modifier.fillMaxSize().padding(16.dp)) {
        item { Text("More", style = MaterialTheme.typography.headlineSmall) }
        items(destinations) { (destination, icon, detail) ->
            Row(
                Modifier.fillMaxWidth().clickable { onSelect(destination) }.padding(vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(icon, destination.title, Modifier.size(28.dp))
                Spacer(Modifier.width(14.dp))
                Column {
                    Text(destination.title, style = MaterialTheme.typography.titleMedium)
                    Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
fun StationIconLegend(vm: StationVM) {
    val entries = buildList {
        add(Triple("healthy", false, "Recent heartbeat with no current operational warning."))
        add(Triple("warning", false, "Heartbeat is becoming stale or telemetry indicates a warning."))
        add(Triple("noRecentHeartbeat", false, "No heartbeat within the recent-heartbeat threshold."))
        add(Triple("inactive", false, "Latest station record is older than the configured Inactive-after period."))
        add(Triple("unknown", false, "Insufficient recent information to determine health."))
        if (vm.highlightBackLevelSoftware) add(Triple("healthy", true, "Otherwise Healthy, but reporting an older PilotAware version. Operational status takes precedence."))
    }
    LazyColumn(Modifier.fillMaxSize().padding(16.dp)) {
        item { Text("Station Icon Legend", style = MaterialTheme.typography.headlineSmall) }
        items(entries) { (health, backLevel, detail) ->
            Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.Top) {
                Icon(healthIcon(health, backLevel), null, tint = healthColour(health, backLevel), modifier = Modifier.size(42.dp))
                Spacer(Modifier.width(14.dp))
                Column {
                    Text(if (backLevel) "Back-level software" else healthTitle(health), style = MaterialTheme.typography.titleMedium)
                    Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {
            Text(
                "Back-level software appears only when highlighting is enabled in Settings.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable fun DetailRows(rows:List<Pair<String,String>>){rows.forEach{(a,b)->Row(Modifier.fillMaxWidth().padding(vertical=4.dp)){Text(a,Modifier.weight(1f));Text(b)}}}
@Composable fun Section(title:String,rows:List<Pair<String,String>>){Text(title,style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=14.dp));DetailRows(rows)}
@Composable fun Settings(vm:StationVM){var server by remember{mutableStateOf(vm.server)};var refresh by remember{mutableIntStateOf(vm.refreshMinutes)};var inactive by remember{mutableIntStateOf(vm.inactiveAfterDays)};Column(Modifier.padding(16.dp)){Text("Settings",style=MaterialTheme.typography.headlineSmall);OutlinedTextField(server,{server=it},label={Text("Server")});Button({vm.server=server;vm.refresh()}){Text("Save & Test")};Text("Refresh interval: $refresh min");Slider(refresh.toFloat(),{refresh=it.toInt().coerceIn(1,10);vm.refreshMinutes=refresh},valueRange=1f..10f,steps=8);Text("Inactive after: $inactive day${if(inactive==1)"" else "s"}");Slider(inactive.toFloat(),{inactive=it.toInt().coerceIn(1,30);vm.inactiveAfterDays=inactive;vm.thresholdChanged()},valueRange=1f..30f,steps=28);Text("Stations not seen for this many days are shown Inactive. Default 2 days.",style=MaterialTheme.typography.bodySmall);Row(verticalAlignment=Alignment.CenterVertically){Text("Highlight back-level software",Modifier.weight(1f));Switch(vm.highlightBackLevelSoftware,{vm.highlightBackLevelSoftware=it})};Text("Off by default. When enabled, only otherwise Healthy stations can use the back-level colour.",style=MaterialTheme.typography.bodySmall)}}
@Composable fun Help(){LazyColumn(Modifier.padding(16.dp)){item{Text("User Guide",style=MaterialTheme.typography.headlineSmall)};item{Text("ATOM Monitor reports PilotAware ATOM ground-station operational health only. It does not display or record aircraft movements. Map and Stations share Status and PilotAware version filters. Inactive after defaults to 2 days. Station Detail shows the effective status icon and explanation, useful live telemetry, and a Google Maps satellite link pinned to the reported station location. Tap a Report count to open the matching filtered Stations list. Report also shares formatted HTML with bar graphs plus CSV station data. Back-level software highlighting is off by default and can be enabled in Settings; operational status always takes precedence. Admin access is paired from an approved local network by scanning the server pairing-page QR code or entering its five-minute one-time code. The per-device credential is protected by Android Keystore; shared administrator secrets are never entered in the app.")}}}

private fun setMarkerIcon(context:Context,health:String)=androidx.core.content.ContextCompat.getDrawable(context,when(health){"inactive","noRecentHeartbeat"->android.R.drawable.presence_busy;"healthy"->android.R.drawable.presence_online;"warning"->android.R.drawable.presence_away;else->android.R.drawable.presence_invisible})
private fun healthIcon(health:String,backLevel:Boolean)=when{backLevel&&health=="healthy"->Icons.Default.Info;health=="healthy"->Icons.Default.CheckCircle;health=="warning"->Icons.Default.Warning;health=="noRecentHeartbeat"->Icons.Default.WifiOff;health=="inactive"->Icons.Default.Cancel;else->Icons.Default.Help}
private fun healthColour(health:String,backLevel:Boolean)=when{backLevel&&health=="healthy"->Color(0xFF7E57C2);health=="healthy"->Color(0xFF2E7D32);health=="warning"->Color(0xFFED6C02);health=="noRecentHeartbeat"->Color(0xFF1976D2);health=="inactive"->Color(0xFFD32F2F);else->Color.Gray}
private fun healthExplanation(v:String)=when(v){"healthy"->"A recent PilotAware heartbeat has been received and no operational warning is currently indicated.";"warning"->"The station is reporting, but its heartbeat is becoming stale or reported telemetry indicates a warning condition.";"noRecentHeartbeat"->"No PilotAware heartbeat has been received within the recent-heartbeat threshold.";"inactive"->"The station's latest record is older than the configured Inactive after period.";else->"There is not enough recent station information to determine its operational health."}
private fun compareVersions(a:String,b:String):Int{val aa=Regex("\\d+").findAll(a).map{it.value.toIntOrNull()?:0}.toList();val bb=Regex("\\d+").findAll(b).map{it.value.toIntOrNull()?:0}.toList();for(i in 0 until maxOf(aa.size,bb.size)){val x=aa.getOrElse(i){0};val y=bb.getOrElse(i){0};if(x!=y)return x.compareTo(y)};return a.compareTo(b,ignoreCase=true)}
private fun healthOrder(v:String)=when(v){"healthy"->0;"warning"->1;"noRecentHeartbeat"->2;"inactive"->3;else->4}
private fun healthTitle(v:String)=when(v){"healthy"->"Healthy";"warning"->"Warning";"noRecentHeartbeat"->"No recent heartbeat";"inactive"->"Inactive";else->"Unknown"}
private fun n(v:String?)=v?:"Not reported"
private fun coordinate(v:Double?)=v?.let{String.format(java.util.Locale.US,"%.5f°",it)}?:"Not reported"
private fun number(v:Double?,suffix:String,decimals:Int)=v?.let{String.format(java.util.Locale.US,"%.${decimals}f%s",it,suffix)}?:"Not reported"
private fun memory(s:Station)=if(s.ramUsedMB!=null&&s.ramTotalMB!=null)String.format(java.util.Locale.US,"%.0f / %.0f MB",s.ramUsedMB,s.ramTotalMB) else "Not reported"
private fun absolute(v:Instant?)=v?.atZone(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm:ss"))?:"Not reported"
private fun fmtTime(v:Instant?)=v?.atZone(ZoneId.systemDefault())?.format(DateTimeFormatter.ofPattern("HH:mm"))?:"Not yet"
private fun relative(v: Instant?): String {
    if (v == null) return "Not reported"

    val seconds = (Instant.now().epochSecond - v.epochSecond).coerceAtLeast(0)
    return if (seconds < 3600) {
        "${seconds / 60} min ago"
    } else if (seconds < 86400) {
        "${seconds / 3600} h ago"
    } else {
        "${seconds / 86400} d ago"
    }
}
private fun iso(v:Instant?)=v?.toString()?:"Not reported"
private fun csvEscape(v:String)="\"${v.replace("\"","\"\"")}\""
private fun htmlEscape(v:String)=v.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;")
