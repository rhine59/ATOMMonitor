package uk.co.rhine59.atommonitor

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private class AdminCredentialStore(private val context:Context) {
    private val prefs=context.getSharedPreferences("atom_admin_secure",Context.MODE_PRIVATE); private val alias="atom_admin_token"
    private fun key():SecretKey { val ks=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}; (ks.getKey(alias,null) as? SecretKey)?.let{return it}
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply { init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build()) }.generateKey() }
    fun save(value:String){ val c=Cipher.getInstance("AES/GCM/NoPadding"); c.init(Cipher.ENCRYPT_MODE,key()); prefs.edit().putString("token",Base64.encodeToString(c.iv+c.doFinal(value.toByteArray()),Base64.NO_WRAP)).apply() }
    fun load():String { val raw=prefs.getString("token",null)?:return ""; return runCatching { val all=Base64.decode(raw,Base64.NO_WRAP); val iv=all.copyOfRange(0,12); val c=Cipher.getInstance("AES/GCM/NoPadding"); c.init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,iv)); String(c.doFinal(all.copyOfRange(12,all.size))) }.getOrDefault("") }
    fun clear(){prefs.edit().remove("token").apply()}
}

private suspend fun adminRequest(server:String,token:String,path:String,method:String="GET",body:String?=null):JSONObject=withContext(Dispatchers.IO){
    val base=server.trim().let{if(it.endsWith('/'))it else "$it/"}; val c=URI(base+path).toURL().openConnection() as HttpURLConnection
    c.requestMethod=method;c.connectTimeout=10_000;c.readTimeout=120_000;c.setRequestProperty("Authorization","Bearer $token");c.setRequestProperty("Content-Type","application/json");c.setRequestProperty("X-ATOM-Admin-Actor","android-admin")
    if(body!=null){c.doOutput=true;c.outputStream.use{it.write(body.toByteArray())}}
    try { val code=c.responseCode; val text=(if(code in 200..299)c.inputStream else c.errorStream).bufferedReader().use{it.readText()}; if(code !in 200..299) error("Admin request failed (HTTP $code)"); JSONObject(text) } finally {c.disconnect()}
}

@Composable fun AdminScreen(vm:StationVM) {
    val context=LocalContext.current; val store=remember{AdminCredentialStore(context)}; val scope=rememberCoroutineScope(); val scanner=remember{GmsBarcodeScanning.getClient(context)}
    var token by remember{mutableStateOf(store.load())}; var pairingCode by remember{mutableStateOf("")}; var summary by remember{mutableStateOf<JSONObject?>(null)}; var busy by remember{mutableStateOf(false)}; var message by remember{mutableStateOf<String?>(null)}; var target by remember{mutableIntStateOf(2)}; var confirm by remember{mutableStateOf(false)}
    fun refresh(){if(token.isBlank())return;scope.launch{busy=true;runCatching{adminRequest(vm.server,token,"api/v1/admin/summary")}.onSuccess{summary=it;target=it.getJSONObject("apiReplicas").getInt("running");message=null}.onFailure{summary=null;message=it.message};busy=false}}
    fun pair(code:String=pairingCode){if(code.isBlank())return;scope.launch{busy=true;runCatching{adminRequest(vm.server,"","api/v1/admin/pair/exchange","POST",JSONObject().put("code",code).put("deviceName","Android phone").toString())}.onSuccess{token=it.getString("deviceToken");store.save(token);pairingCode="";refresh()}.onFailure{message=it.message};busy=false}}
    fun scanPairingCode(){scanner.startScan().addOnSuccessListener{barcode->runCatching{JSONObject(barcode.rawValue?:"").getString("code")}.onSuccess{pairingCode=it;pair(it)}.onFailure{message="That QR code is not an ATOMMonitor pairing code."}}.addOnFailureListener{message=it.message}}
    LaunchedEffect(Unit){if(token.isNotBlank())refresh()}
    if(summary==null){ Column(Modifier.fillMaxSize().padding(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text("Admin",style=MaterialTheme.typography.headlineSmall);Text("Restricted administration",style=MaterialTheme.typography.titleMedium);if(token.isBlank()){Button(onClick={scanPairingCode()}){Text("Scan pairing QR code")};OutlinedTextField(pairingCode,{pairingCode=it.uppercase()},label={Text("One-time pairing code")},singleLine=true,modifier=Modifier.fillMaxWidth());Button(enabled=pairingCode.isNotBlank()&&!busy,onClick={pair()}){Text("Pair this device")};Text("On a computer connected to your home network, open the server address followed by /api/v1/admin/pair. Enter the displayed code here; it expires after five minutes.",style=MaterialTheme.typography.bodySmall)}else{Button(enabled=!busy,onClick={refresh()}){Text("Unlock")};OutlinedButton(onClick={scope.launch{runCatching{adminRequest(vm.server,token,"api/v1/admin/device","DELETE")};store.clear();token="";summary=null}}){Text("Remove administrator access")};Text("This phone is paired. Its private credential is encrypted with Android Keystore.",style=MaterialTheme.typography.bodySmall)};message?.let{Text(it,color=MaterialTheme.colorScheme.error)}} }
    else { val s=summary!!; val reps=s.getJSONObject("apiReplicas"); val containers=s.getJSONArray("containers"); LazyColumn(Modifier.fillMaxSize().padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){item{Text("Admin",style=MaterialTheme.typography.headlineSmall)};item{ElevatedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){Text("API service",style=MaterialTheme.typography.titleMedium);Text("Running ${reps.getInt("running")} • Healthy ${reps.getInt("healthy")}");Row{OutlinedButton(onClick={if(target>1)target--}){Text("−")};Text("  $target replicas  ",modifier=Modifier.padding(top=12.dp));OutlinedButton(onClick={if(target<4)target++}){Text("+")}};Button(enabled=!busy&&target!=reps.getInt("running"),onClick={confirm=true}){Text("Apply change")}}}};items(containers.length()){i->val item=containers.getJSONObject(i);ListItem(headlineContent={Text(item.getString("name"))},supportingContent={Text("${item.getString("service")} • ${item.getString("state")}")},trailingContent={Text(item.getString("health"))})};message?.let{item{Text(it)}};item{Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Button(onClick={refresh()}){Text("Refresh")};OutlinedButton(onClick={summary=null}){Text("Lock Admin")}}}} }
    if(busy) Box(Modifier.fillMaxSize().padding(24.dp)){CircularProgressIndicator()}
    if(confirm) AlertDialog(onDismissRequest={confirm=false},title={Text("Scale API to $target replicas?")},text={Text("Only atom-api will change. The server waits until every requested replica is healthy.")},confirmButton={Button(onClick={confirm=false;scope.launch{busy=true;runCatching{adminRequest(vm.server,token,"api/v1/admin/api-scale","POST",JSONObject().put("replicas",target).put("confirmed",true).toString())}.onSuccess{message="Scale complete: ${it.getInt("healthyReplicas")} healthy";refresh()}.onFailure{message=it.message};busy=false}}){Text("Apply")}},dismissButton={TextButton(onClick={confirm=false}){Text("Cancel")}})
}
