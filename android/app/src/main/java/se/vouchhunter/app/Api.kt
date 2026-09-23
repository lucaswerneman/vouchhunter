package se.vouchhunter.app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class SessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("session", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("vh.session", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("vh.session", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    fun read(): String? = runCatching {
        val raw = prefs.getString("token", null) ?: return null
        val chunks = raw.split(":")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, Base64.decode(chunks[0], Base64.NO_WRAP)))
        String(cipher.doFinal(Base64.decode(chunks[1], Base64.NO_WRAP)), Charsets.UTF_8)
    }.getOrNull()
    fun save(token: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val value = Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(cipher.doFinal(token.toByteArray()), Base64.NO_WRAP)
        check(prefs.edit().putString("token", value).commit()) { "Kunde inte spara inloggningen." }
    }
    fun clear() { prefs.edit().remove("token").apply() }
}
class Api(context: Context) {
    private val cache = java.io.File(context.cacheDir, "VouchhunterModels")
    val session = SessionStore(context)
    suspend fun request(path: String, body: JSONObject? = null): JSONObject = withContext(Dispatchers.IO) {
        check(!BuildConfig.API_BASE_URL.contains("configuration-required.invalid")) { "Serveradressen är inte konfigurerad ännu." }
        val connection = URL(BuildConfig.API_BASE_URL + "/api" + path).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15000; connection.readTimeout = 20000
            connection.instanceFollowRedirects = false
            session.read()?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
            if (body != null) {
                connection.requestMethod = "POST"; connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.use { it.write(body.toString().toByteArray()) }
            }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val result = JSONObject(stream?.bufferedReader()?.use { it.readText() } ?: "{}")
            check(code in 200..299) { result.optString("error", "Servern svarade inte. Försök igen.") }
            result
        } finally { connection.disconnect() }
    }
    suspend fun modelFile(assetID: String): java.io.File = withContext(Dispatchers.IO) {
        require(assetID.matches(Regex("[a-f0-9]{24}"))) { "Ogiltigt 3D-objekt." }
        cache.mkdirs()
        val file=java.io.File(cache,"$assetID.glb")
        if(file.isFile) return@withContext file
        val connection=URL(BuildConfig.API_BASE_URL+"/api/assets/"+assetID).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout=15000;connection.readTimeout=30000
            connection.instanceFollowRedirects=false
            session.read()?.let{connection.setRequestProperty("Authorization","Bearer $it")}
            check(connection.responseCode==200){"3D-objektet kunde inte hämtas."}
            val output=java.io.ByteArrayOutputStream()
            connection.inputStream.use { input ->
                val buffer=ByteArray(8192)
                while(true){val count=input.read(buffer);if(count<0)break;check(output.size()+count<=12*1024*1024){"3D-objektet är för stort."};output.write(buffer,0,count)}
            }
            val bytes=output.toByteArray()
            check(bytes.size>=20 && String(bytes.copyOfRange(0,4),Charsets.US_ASCII)=="glTF"){"Ogiltig 3D-modell."}
            if(file.createNewFile())file.outputStream().use{it.write(bytes)}
            file
        } finally {connection.disconnect()}
    }

}
