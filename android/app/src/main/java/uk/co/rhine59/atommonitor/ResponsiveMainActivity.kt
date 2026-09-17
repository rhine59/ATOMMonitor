package uk.co.rhine59.atommonitor

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.viewmodel.compose.viewModel
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

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
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Tab.entries.forEach { item ->
                        val selected = tab == item
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
                                    Tab.Settings -> Icons.Default.Settings
                                    Tab.Help -> Icons.Default.Help
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
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when (tab) {
                Tab.Map -> ResponsiveMapScreen(vm) { detail = it }
                Tab.Stations -> StationList(vm.stations, vm) { detail = it }
                Tab.Favourites -> StationList(vm.stations.filter { vm.favourites().contains(it.id) }, vm) { detail = it }
                Tab.Report -> ReportScreen(vm)
                Tab.Settings -> Settings(vm)
                Tab.Help -> Help()
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
private fun ResponsiveMapScreen(
    vm: StationVM,
    onStation: (Station) -> Unit
) {
    var query by remember { mutableStateOf("") }
    val shown = vm.filtered(query = query)

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
                                setOnMarkerClickListener { _, _ ->
                                    onStation(station)
                                    true
                                }
                            }
                        )
                    }
                }
                map.invalidate()
            }
        )

        Surface(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .padding(8.dp),
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
                                "${vm.stations.size} stations"
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = if (vm.error != null) Color.Red else LocalContentColor.current
                        )
                    }
                    FilterButton(vm)
                    IconButton(onClick = vm::refresh) {
                        Icon(Icons.Default.Refresh, "Refresh")
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
}

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
