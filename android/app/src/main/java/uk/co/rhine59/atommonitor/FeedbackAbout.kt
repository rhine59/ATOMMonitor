package uk.co.rhine59.atommonitor

import android.content.Context
import android.os.Build
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier\nimport androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI

@Composable
fun FeedbackScreen(server: String) {
    val context = androidx.compose.ui.platform.LocalContext.current
    FeedbackContent(server, context)
}

@Composable
private fun FeedbackContent(server: String, context: Context) {
    var rating by remember { mutableIntStateOf(0) }
    var comments by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Feedback", style = MaterialTheme.typography.headlineSmall)
            Text("Your rating")
            Row { (1..5).forEach { value -> IconButton(onClick = { rating = value }) { Icon(if (value <= rating) Icons.Default.Star else Icons.Default.StarBorder, "$value stars") } } }
            OutlinedTextField(value = comments, onValueChange = { if (it.length <= 4000) comments = it }, label = { Text("Comments or suggestions") }, minLines = 4, modifier = Modifier.fillMaxWidth())
            Text("Your feedback is sent privately to Richard Hine. The destination email address is not shown by the app.", style = MaterialTheme.typography.bodySmall)
            result?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
        Button(enabled = rating in 1..5 && !sending, onClick = {
            sending = true; result = null
            scope.launch {
                result = runCatching { sendFeedback(server, rating, comments, context) }.fold(
                    onSuccess = { "Thank you. Your feedback has been sent to Richard Hine." },
                    onFailure = { "Feedback could not be sent. Please try again later." })
                sending = false
            }
        }) { if (sending) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) else Text("Send Feedback") }
    }
}

@Composable
fun AboutScreen() {
    val context = androidx.compose.ui.platform.LocalContext.current
    val p = remember { context.packageManager.getPackageInfo(context.packageName, 0) }\n    val uriHandler = LocalUriHandler.current
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("About ATOM Monitor", style = MaterialTheme.typography.headlineSmall)
            Text("Monitors the operational health and technical status of PilotAware ATOM ground stations.")
            Text("Version: " + (p.versionName ?: "Unknown"))
            Text("Build: " + p.longVersionCode)
            Text("Version / Build: " + (p.versionName ?: "Unknown") + " (" + p.longVersionCode + ")")
            Text("Platform: Android " + Build.VERSION.RELEASE)
            HorizontalDivider()
            Text("Credits", style = MaterialTheme.typography.titleMedium)
            Text("Created by Richard Hine")
            Text("PilotAware and ATOM are acknowledged as the technologies and ground-station network monitored by this application.")\n            TextButton(onClick = { uriHandler.openUri("https://www.pilotaware.com/atom") }) { Text("PilotAware ATOM") }
            Text("PilotAware® is a registered trademark of PilotAware Ltd. ATOM Monitor is an independent project and is not affiliated with, endorsed by or sponsored by PilotAware Ltd.", style = MaterialTheme.typography.bodySmall)
            HorizontalDivider()
            Text("Copyright", style = MaterialTheme.typography.titleMedium)
            Text("© 2026 Richard Hine. All rights reserved.")
            HorizontalDivider()
            Text("ATOM Monitor does not display, record or retain aircraft movements, tracks or aircraft identities.")
    }
}

private suspend fun sendFeedback(server: String, rating: Int, comments: String, context: Context) = withContext(Dispatchers.IO) {
    val base = server.trim().let { if (it.endsWith('/')) it else "$it/" }
    val connection = URI(base + "api/v1/feedback").toURL().openConnection() as HttpURLConnection
    connection.requestMethod = "POST"; connection.connectTimeout = 10000; connection.readTimeout = 15000
    connection.setRequestProperty("Content-Type", "application/json"); connection.doOutput = true
    val p = context.packageManager.getPackageInfo(context.packageName, 0)
    val payload = JSONObject().put("rating", rating).put("comments", comments).put("platform", "Android")
        .put("version", (p.versionName ?: "Unknown") + " (" + p.longVersionCode + ")")
        .put("osVersion", "Android " + Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ")")
    connection.outputStream.use { it.write(payload.toString().toByteArray()) }
    try { if (connection.responseCode !in 200..299) error("HTTP " + connection.responseCode) } finally { connection.disconnect() }
}
