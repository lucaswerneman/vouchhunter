package se.vouchhunter.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.text.InputType
import android.view.View
import android.widget.*
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.lifecycleScope
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.MarkerOptions
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.text.DateFormat
import java.util.Date

class MainActivity : ComponentActivity(), LocationListener {
    private lateinit var api: Api
    private lateinit var root: LinearLayout
    private var map: MapView? = null
    private var location: Location? = null
    private var campaign: JSONObject? = null
    private val manager by lazy { getSystemService(LOCATION_SERVICE) as LocationManager }
    private val permissions = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { if (it[Manifest.permission.ACCESS_FINE_LOCATION] == true) locate() else message("Exakt position behövs för att samla föremål.") }
    private val capture = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val stop = result.data?.getStringExtra("stop_id")
        if (result.resultCode == RESULT_OK && stop != null) collect(stop)
    }
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); api = Api(this); if (api.session.read() == null) login(false) else explore() }
    private fun layout(title: String) {
        map?.onPause(); map?.onDestroy(); map = null
        root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(24, 48, 24, 32); setBackgroundColor(HuntStyle.canvas) }
        setContentView(ScrollView(this).apply { addView(root) }); heading(title)
    }
    private fun heading(text: String) { root.addView(TextView(this).apply { this.text = text; textSize = 30f; HuntStyle.text(this); setPadding(0,20,0,20); typeface = android.graphics.Typeface.DEFAULT_BOLD }) }
    private fun text(value: String, size: Float = 16f) { root.addView(TextView(this).apply { text = value; textSize = size; setPadding(0,10,0,12); HuntStyle.text(this) }) }
    private fun button(label: String, action: () -> Unit) { root.addView(Button(this).apply { text = label; HuntStyle.button(this); layoutParams = LinearLayout.LayoutParams(-1, -2).apply { topMargin = (12 * resources.displayMetrics.density).toInt() }; setOnClickListener { action() } }) }
    private fun input(label: String, kind: Int): EditText {
        text(label,13f)
        return EditText(this).apply { inputType = kind; HuntStyle.text(this); backgroundTintList = android.content.res.ColorStateList.valueOf(HuntStyle.line); setSingleLine(); root.addView(this) }
    }
    private fun message(value: String) { android.app.AlertDialog.Builder(this, android.app.AlertDialog.THEME_DEVICE_DEFAULT_DARK).setMessage(value).setPositiveButton("OK",null).show() }
    private fun run(action: suspend () -> Unit) { lifecycleScope.launch { try { action() } catch (e: Exception) { if (e is kotlinx.coroutines.CancellationException) throw e; message(e.message ?: "Något gick fel.") } } }
    private fun login(register: Boolean) {
        layout("vouchhunter."); heading("Nästa upptäckt väntar runt hörnet."); text("Hitta kampanjer. Samla föremål. Få din belöning.")
        val name = if (register) input("Ditt namn",InputType.TYPE_CLASS_TEXT) else null
        val email = input("E-postadress",InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS)
        val password = input("Lösenord, minst 10 tecken",InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD)
        button(if(register) "Skapa konto" else "Logga in") {
            run { val data = JSONObject().put("email",email.text.toString()).put("password",password.text.toString()).put("name",name?.text?.toString() ?: "").put("native",true)
                val result = api.request(if(register) "/register" else "/login",data); api.session.save(result.getString("token")); explore() }
        }
        button(if(register) "Har du ett konto? Logga in" else "Ny här? Skapa konto") { login(!register) }
    }
    private fun explore() {
        layout("Ut och upptäck."); text("Din nästa belöning börjar med en promenad.")
        button("Dina vouchers") { wallet() }; button("Logga ut") { run { api.request("/logout",JSONObject()); api.session.clear(); login(false) } }
        run {
            val list = api.request("/campaigns").getJSONArray("campaigns")
            val campaigns = (0 until list.length()).map { list.getJSONObject(it) }
            val stops = campaigns.flatMap { c -> val a=c.getJSONArray("stops"); (0 until a.length()).map{a.getJSONObject(it)} }
            showMap(stops)
            if(campaigns.isEmpty()) text("Det finns inga öppna kampanjer ännu. Nya jakter visas här när de publiceras.")
            campaigns.forEach { c -> heading(c.getString("title")); text(c.getString("reward")); text("${c.getInt("target")} objekt att samla",13f); button("Öppna jakten") { hunt(c) } }
            val id = intent?.data?.lastPathSegment
            if(id != null && id.matches(Regex("[a-f0-9]{24}"))) { intent.data=null; hunt(api.request("/campaigns/$id")) }
        }
    }
    private fun showMap(stops: List<JSONObject>) {
        val key = packageManager.getApplicationInfo(packageName,PackageManager.GET_META_DATA).metaData?.getString("com.google.android.geo.API_KEY")
        if(key.isNullOrBlank()) { text("Karttjänsten behöver konfigureras för den här appversionen.",13f); return }
        map = MapView(this).also { view ->
            view.onCreate(null);root.addView(view,LinearLayout.LayoutParams(-1,650));view.onResume()
            view.getMapAsync { google ->
                google.setMapStyle(com.google.android.gms.maps.model.MapStyleOptions("""[{"elementType":"geometry","stylers":[{"color":"#f2f2f2"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#666666"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f2f2f2"}]},{"featureType":"poi","stylers":[{"visibility":"off"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#dbe5ec"}]}]"""))
                google.isBuildingsEnabled = true
                stops.forEach { s -> google.addMarker(MarkerOptions().position(LatLng(s.getDouble("lat"),s.getDouble("lon"))).title(s.getString("name"))) }
                val first=stops.firstOrNull();google.moveCamera(CameraUpdateFactory.newLatLngZoom(if(first==null) LatLng(59.3326,18.0649) else LatLng(first.getDouble("lat"),first.getDouble("lon")),14f))
            }
        }
    }
    private fun hunt(c: JSONObject) {
        campaign=c;layout(c.getString("title"));text(c.getString("description"));heading(c.getString("reward"));locate()
        run {
            val h=api.request("/hunts/"+c.getString("id")).optJSONObject("hunt")
            val collected=h?.optJSONArray("collected");val ids=if(collected==null) emptyList() else (0 until collected.length()).map{collected.getString(it)}
            text("${ids.size} av ${c.getInt("target")} objekt insamlade")
            if(h == null || h.getLong("expires")<System.currentTimeMillis()/1000) {
                text("En belöning reserveras i upp till 60 minuter, senast till kampanjens slut.",13f)
                button("Starta jakten") { run {api.request("/hunts/${c.getString("id")}/start",JSONObject());hunt(c)} }
            }
            val stops=c.getJSONArray("stops");val list=(0 until stops.length()).map{stops.getJSONObject(it)};showMap(list)
            list.forEach { s ->
                val done=ids.contains(s.getString("id"));text(s.getString("name")+if(done) " · Insamlad" else "")
                if(!done && h!=null && h.getLong("expires")>System.currentTimeMillis()/1000) button("Samla föremålet") {
                    val here=location;val result=FloatArray(1)
                    if(here==null || here.accuracy>35 || System.currentTimeMillis()-here.time>45000) message("Väntar på en noggrann position. Försök igen utomhus.")
                    else {Location.distanceBetween(here.latitude,here.longitude,s.getDouble("lat"),s.getDouble("lon"),result)
                        if(result[0]>s.getInt("radius")) message("Gå närmare platsen. Du är ${result[0].toInt()} meter bort.")
                        else {
                            val model=c.optJSONObject("model")
                            if(model==null)message("Kampanjen saknar ett 3D-objekt.")
                            else capture.launch(Intent(this@MainActivity,CaptureActivity::class.java).putExtra("stop_id",s.getString("id")).putExtra("asset_id",model.getString("glb_asset_id")))
                        } }
                }
            }
            text(c.getString("terms"),13f);text("Lös in hos "+c.getString("venue"),13f);button("Till dina vouchers"){wallet()};button("Alla kampanjer"){explore()}
        }
    }
    private fun collect(stop: String) {
        val c=campaign ?: return;val here=location ?: return message("Din position saknas. Försök igen.")
        run { api.request("/hunts/${c.getString("id")}/collect",JSONObject().put("stop_id",stop).put("lat",here.latitude).put("lon",here.longitude).put("accuracy",here.accuracy).put("captured_at",here.time/1000));hunt(c);message("Föremålet är insamlat!") }
    }
    private fun wallet() {
        layout("Dina vouchers");button("Till kartan"){explore()}
        run {
            val list=api.request("/vouchers").getJSONArray("vouchers")
            if(list.length()==0)text("Slutför en jakt så sparas din belöning här.")
            for(i in 0 until list.length()) {
                val v=list.getJSONObject(i);heading(v.getString("reward"));text(v.getString("venue"))
                val valid=v.isNull("redeemed") && v.getLong("expires")>System.currentTimeMillis()/1000
                if(valid) {
                    val bits=MultiFormatWriter().encode(v.getString("code"),BarcodeFormat.QR_CODE,600,600)
                    val bitmap=Bitmap.createBitmap(600,600,Bitmap.Config.ARGB_8888)
                    for(x in 0 until 600)for(y in 0 until 600)bitmap.setPixel(x,y,if(bits[x,y]) Color.BLACK else Color.WHITE)
                    root.addView(ImageView(this@MainActivity).apply{setImageBitmap(bitmap);contentDescription="QR-kod för inlösen"},LinearLayout.LayoutParams(-1,600))
                    text(v.getString("code"),12f)
                }
                text(if(!v.isNull("redeemed")) "Inlöst" else if(valid) "Visa för personalen" else "Giltighetstiden har gått ut")
                text("Gäller till "+DateFormat.getDateInstance().format(Date(v.getLong("expires")*1000)),13f);text(v.getString("terms"),13f)
            }
        }
    }
    private fun locate() {
        if(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED) {permissions.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION));return}
        try {manager.requestLocationUpdates(LocationManager.GPS_PROVIDER,2000,1f,this)}catch(e:Exception){message("Aktivera platsåtkomst för att samla föremål.")}
    }
    override fun onLocationChanged(value: Location) { location=value }
    override fun onResume(){super.onResume();map?.onResume()}
    override fun onPause(){map?.onPause();super.onPause()}
    override fun onDestroy(){manager.removeUpdates(this);map?.onDestroy();super.onDestroy()}
}
