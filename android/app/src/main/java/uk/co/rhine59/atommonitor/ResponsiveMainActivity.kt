package uk.co.rhine59.atommonitor

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
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import java.net.HttpURLConnection
import java.net.URI
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.*

class ResponsiveMainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Configuration.getInstance().userAgentValue = packageName
        setContent { MaterialTheme { ResponsiveApp() } }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ResponsiveApp(vm: StationVM = viewModel()) {
    var tab by remember { mutableStateOf(Tab.Map) }
    var detail by remember { mutableStateOf<Station?>(null) }

    Scaffold(
        contentWindowInsets = WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Top),
        bottomBar = {
            Surface(tonalElevation = 3.dp) {
                Row(
                    modifier = Modifier.fillMaxWidth().navigationBarsPadding(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Tab.entries.forEach { item ->
                        val selected = tab == item
                        Column(
                            modifier = Modifier.weight(1f).clickable { tab = item }.padding(vertical = 6.dp),
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
                                },
                                contentDescription = item.title,
                                modifier = Modifier.size(22.dp),
                                tint = if (selected) MaterialTheme.colorScheme.primary else LocalContentColor.current
                            )
                            Text(
                                text = item.title,
                                maxLines = 1,
                                fontSize = 10.sp,
                                color = if (selected) MaterialTheme.colorScheme.primary else LocalContentColor.current
                            )
                        }
                    }
                }
            }
        }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (tab) {
                Tab.Map -> ResponsiveMapScreen(vm) { detail = it }
                Tab.Stations -> StationList(vm.stations, vm) { detail = it }
                Tab.Favourites -> StationList(vm.stations.filter { vm.favourites().contains(it.id) }, vm) { detail = it }
                Tab.Report -> ReportScreen(vm) { tab = Tab.Stations }
                Tab.Admin -> AdminScreen(vm)
                Tab.Settings -> ResponsiveSettings(vm)
                Tab.Help -> Help()
                Tab.Feedback -> FeedbackScreen(vm.server)
                Tab.About -> AboutScreen()
            }
        }
    }

    detail?.let { station ->
        ModalBottomSheet(onDismissRequest = { detail = null }) {
            Detail(
                station,
                vm.displayHealth(station),
                vm.isBackLevel(station),
                vm.favourites().contains(station.id)
            ) { vm.toggleFavourite(station.id) }
        }
    }
}

@Composable
private fun ResponsiveMapScreen(vm: StationVM, onStation: (Station) -> Unit) {
    var query by remember { mutableStateOf("") }
    var mapRef by remember { mutableStateOf<MapView?>(null) }
    var homeMessage by remember { mutableStateOf<String?>(null) }
    val shown = vm.filtered(query = query)

    fun focusHome(filtered: Boolean) {
        val map = mapRef ?: return
        val home = vm.stations.firstOrNull { it.id == vm.home }
        val homeLat = home?.latitude
        val homeLon = home?.longitude
        if (vm.home.isBlank()) {
            homeMessage = "No home station set"
            return
        }
        if (homeLat == null || homeLon == null) {
            homeMessage = "Home station location not reported"
            return
        }
        val target = if (filtered && vm.hasFilters) {
            shown.filter { it.latitude != null && it.longitude != null }
                .minByOrNull { distanceKm(homeLat, homeLon, it.latitude!!, it.longitude!!) }
        } else home
        val lat = target?.latitude
        val lon = target?.longitude
        if (lat == null || lon == null) {
            map.controller.setZoom(6.0)
            map.controller.setCenter(GeoPoint(54.5, -3.0))
        } else {
            map.controller.setZoom(9.0)
            map.controller.setCenter(GeoPoint(lat, lon))
        }
        map.invalidate()
    }

    LaunchedEffect(mapRef, vm.stations.size, vm.home) {
        if (mapRef != null && vm.stations.isNotEmpty() && vm.home.isNotBlank()) focusHome(false)
    }
    LaunchedEffect(mapRef, vm.selectedHealth, vm.selectedVersions) {
        if (mapRef == null || vm.stations.isEmpty()) return@LaunchedEffect
        if (vm.hasFilters) focusHome(true)
        else if (vm.home.isNotBlank()) focusHome(false)
        else {
            mapRef?.controller?.setZoom(6.0)
            mapRef?.controller?.setCenter(GeoPoint(54.5, -3.0))
            mapRef?.invalidate()
        }
    }

    Box(Modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { context ->
                MapView(context).apply {
                    setTileSource(TileSourceFactory.MAPNIK)
                    setMultiTouchControls(true)
                    controller.setZoom(6.0)
                    controller.setCenter(GeoPoint(54.5, -3.0))
                }
            },
            update = { map ->
                mapRef = map
                map.overlays.removeAll { it is Marker }
                shown.forEach { station ->
                    val latitude = station.latitude
                    val longitude = station.longitude
                    if (latitude != null && longitude != null) {
                        map.overlays.add(
                            Marker(map).apply {
                                position = GeoPoint(latitude, longitude)
                                title = station.name
                                snippet = "${responsiveHealthTitle(vm.displayHealth(station))} • ${station.pilotAwareVersion ?: "Version not reported"}"
                                icon = responsiveMarkerIcon(map.context, vm.displayHealth(station))
                                setOnMarkerClickListener { _, _ -> onStation(station); true }
                            }
                        )
                    }
                }
                map.invalidate()
            }
        )

        Surface(
            modifier = Modifier.align(Alignment.TopCenter).fillMaxWidth().padding(8.dp),
            shape = MaterialTheme.shapes.large,
            tonalElevation = 6.dp,
            shadowElevation = 6.dp
        ) {
            Column(Modifier.padding(horizontal = 10.dp, vertical = 6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Stations", style = MaterialTheme.typography.titleMedium)
                        Text(
                            text = if (vm.error != null) {
                                "No Network • ${vm.stations.size} stations"
                            } else {
                                "Updated ${responsiveTime(vm.lastUpdated)} • ${vm.stations.size} stations"
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = if (vm.error != null) Color.Red else LocalContentColor.current
                        )
                    }
                    FilterButton(vm)
                    IconButton(onClick = { focusHome(false) }) { Icon(Icons.Default.Home, "Go to home station") }
                    IconButton(onClick = vm::refresh) { Icon(Icons.Default.Refresh, "Refresh") }
                }
                if (vm.hasFilters) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Filtered: ${shown.size} of ${vm.stations.size}", style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                        TextButton(onClick = vm::clearFilters, contentPadding = PaddingValues(horizontal = 4.dp)) { Text("Clear filters") }
                    }
                }
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text("Find station") },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }

    homeMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { homeMessage = null },
            confirmButton = { TextButton(onClick = { homeMessage = null }) { Text("OK") } },
            title = { Text("Home station") },
            text = { Text(message) }
        )
    }
}

@Composable
private fun ResponsiveSettings(vm: StationVM) {
    var server by remember { mutableStateOf(vm.server) }
    var refresh by remember { mutableIntStateOf(vm.refreshMinutes) }
    var inactive by remember { mutableIntStateOf(vm.inactiveAfterDays) }
    var showHomePicker by remember { mutableStateOf(false) }
    var testResult by remember { mutableStateOf<String?>(null) }
    var testing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val selectedHome = vm.stations.firstOrNull { it.id == vm.home }

    LazyColumn(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { Text("Settings", style = MaterialTheme.typography.headlineSmall) }
        item {
            OutlinedTextField(
                value = server,
                onValueChange = { server = it },
                label = { Text("Server") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { vm.server = server; vm.refresh() }) { Text("Save") }
                Button(
                    enabled = !testing,
                    onClick = {
                        vm.server = server
                        testing = true
                        testResult = null
                        scope.launch {
                            testResult = runCatching { testReady(server) }
                                .fold(onSuccess = { "Connection OK • $it confirmed stations" }, onFailure = { "Connection failed • ${it.message ?: "Unknown error"}" })
                            testing = false
                        }
                    }
                ) { if (testing) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) else Text("Test Connection") }
            }
        }
        testResult?.let { result -> item { Text(result, style = MaterialTheme.typography.bodySmall) } }
        item { HorizontalDivider(); Text("Home station", style = MaterialTheme.typography.titleMedium) }
        item {
            OutlinedButton(onClick = { showHomePicker = true }, modifier = Modifier.fillMaxWidth()) {
                Text(selectedHome?.name ?: if (vm.home.isBlank()) "Not set" else vm.home, modifier = Modifier.weight(1f))
                Icon(Icons.Default.ArrowDropDown, "Choose Home ATOM station")
            }
        }
        item { Text("Home is used by the map Home control and as the origin for filtered map focus. Device location is not required.", style = MaterialTheme.typography.bodySmall) }
        item { HorizontalDivider(); Text("Refresh interval: $refresh min") }
        item { Slider(refresh.toFloat(), { refresh = it.toInt().coerceIn(1, 10); vm.refreshMinutes = refresh }, valueRange = 1f..10f, steps = 8) }
        item { Text("Inactive after: $inactive day${if (inactive == 1) "" else "s"}") }
        item { Slider(inactive.toFloat(), { inactive = it.toInt().coerceIn(1, 30); vm.inactiveAfterDays = inactive; vm.thresholdChanged() }, valueRange = 1f..30f, steps = 28) }
        item { Text("Stations not seen for this many days are shown Inactive. Default 2 days.", style = MaterialTheme.typography.bodySmall) }
        item { Row(verticalAlignment = Alignment.CenterVertically) { Text("Highlight back-level software", Modifier.weight(1f)); Switch(checked = vm.highlightBackLevelSoftware, onCheckedChange = { vm.highlightBackLevelSoftware = it }) } }
        item { Text("Off by default. When enabled, only otherwise Healthy stations can use the configured back-level colour. Operational status always takes precedence.", style = MaterialTheme.typography.bodySmall) }
    }

    if (showHomePicker) {
        HomeStationPicker(
            stations = vm.stations,
            selectedID = vm.home,
            onSelect = { vm.home = it; showHomePicker = false },
            onDismiss = { showHomePicker = false }
        )
    }
}

@Composable
private fun HomeStationPicker(
    stations: List<Station>,
    selectedID: String,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var query by remember { mutableStateOf("") }
    val filtered = remember(stations, query) {
        stations.sortedBy { it.name.lowercase() }.filter {
            query.isBlank() || it.name.contains(query, ignoreCase = true) || it.id.contains(query, ignoreCase = true)
        }
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        title = { Text("Choose Home ATOM station") },
        text = {
            Column(Modifier.fillMaxWidth()) {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text("Find station") },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))
                LazyColumn(Modifier.fillMaxWidth().heightIn(max = 420.dp)) {
                    item {
                        ListItem(
                            headlineContent = { Text("Not set") },
                            trailingContent = { if (selectedID.isBlank()) Icon(Icons.Default.Check, "Selected") },
                            modifier = Modifier.clickable { onSelect("") }
                        )
                    }
                    items(filtered, key = { it.id }) { station ->
                        ListItem(
                            headlineContent = { Text(station.name) },
                            supportingContent = { if (station.id != station.name) Text(station.id) },
                            trailingContent = { if (station.id == selectedID) Icon(Icons.Default.Check, "Selected") },
                            modifier = Modifier.clickable { onSelect(station.id) }
                        )
                    }
                }
            }
        }
    )
}

private suspend fun testReady(server: String): Int = withContext(Dispatchers.IO) {
    val base = server.trim().let { if (it.endsWith('/')) it else "$it/" }
    val connection = URI(base + "ready").toURL().openConnection() as HttpURLConnection
    connection.connectTimeout = 10_000
    connection.readTimeout = 12_000
    try {
        val code = connection.responseCode
        if (code !in 200..299) error("HTTP $code")
        val body = connection.inputStream.bufferedReader().use { it.readText() }
        val json = JSONObject(body)
        if (json.optString("status") != "ready" || json.optString("database") != "ok") error("Service not ready")
        json.optInt("confirmedStations", -1).also { if (it < 0) error("Station count not reported") }
    } finally {
        connection.disconnect()
    }
}

private fun distanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val radius = 6371.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a = sin(dLat / 2).pow(2) + cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2).pow(2)
    return radius * 2 * atan2(sqrt(a), sqrt(1 - a))
}

private fun responsiveTime(value: Instant?): String = value?.let {
    DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.systemDefault()).format(it)
} ?: "—"
private fun responsiveMarkerIcon(context: android.content.Context, health: String) =
    androidx.core.content.ContextCompat.getDrawable(
        context,
        when (health) {
            "inactive", "noRecentHeartbeat" -> android.R.drawable.presence_busy
            "healthy" -> android.R.drawable.presence_online
            "warning" -> android.R.drawable.presence_away
            else -> android.R.drawable.presence_invisible
        }
    )

private fun responsiveHealthTitle(value: String) = when (value) {
    "healthy" -> "Healthy"
    "warning" -> "Warning"
    "noRecentHeartbeat" -> "No recent heartbeat"
    "inactive" -> "Inactive"
    else -> "Unknown"
}
