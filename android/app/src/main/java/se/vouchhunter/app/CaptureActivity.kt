package se.vouchhunter.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.lifecycleScope
import com.google.ar.core.Plane
import com.google.ar.core.TrackingState
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.launch

class CaptureActivity: ComponentActivity() {
    private var scene: ARSceneView? = null
    private var placed=false
    private var loaded=false
    private lateinit var instruction:TextView
    private lateinit var collect:Button
    private val permission=registerForActivityResult(ActivityResultContracts.RequestPermission()){if(it)showAR()else{instruction.text="Kameraåtkomst behövs för att visa objektet."}}
    override fun onCreate(savedInstanceState:Bundle?) {
        super.onCreate(savedInstanceState)
        instruction=TextView(this).apply{text="Rikta kameran mot marken.";textSize=20f;HuntStyle.text(this);setBackgroundColor(HuntStyle.canvas)}
        if(checkSelfPermission(Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)showAR()
        else {setContentView(instruction);permission.launch(Manifest.permission.CAMERA)}
    }
    private fun showAR() {
        val root=FrameLayout(this);setContentView(root)
        val view=ARSceneView(this,sharedActivity=this,sharedLifecycle=lifecycle);scene=view;root.addView(view)
        instruction.setBackgroundColor(0xee000000.toInt());instruction.setPadding(24,48,24,24)
        root.addView(instruction,FrameLayout.LayoutParams(-1,-2,Gravity.TOP))
        collect=Button(this).apply{HuntStyle.button(this);text="Samla föremålet";isEnabled=false;setOnClickListener{setResult(RESULT_OK,Intent().putExtra("stop_id",intent.getStringExtra("stop_id")));finish()}}
        root.addView(collect,FrameLayout.LayoutParams(-1,160,Gravity.BOTTOM))
        view.onSessionFailed={instruction.text="AR kunde inte startas på enheten. Kontrollera att Google Play Services för AR är installerat."}
        view.onSessionUpdated={session,frame ->
            collect.isEnabled=loaded && frame.camera.trackingState==TrackingState.TRACKING
            if(!placed) {
                val plane=session.getAllTrackables(Plane::class.java).firstOrNull{it.type==Plane.Type.HORIZONTAL_UPWARD_FACING && it.trackingState==TrackingState.TRACKING}
                if(plane!=null) {
                    placed=true
                    val anchor=AnchorNode(view.engine,plane.createAnchor(plane.centerPose));view.addChildNode(anchor)
                    lifecycleScope.launch {
                        try {
                            val assetID=intent.getStringExtra("asset_id") ?: error("Kampanjen saknar 3D-objekt.")
                            val file=Api(this@CaptureActivity).modelFile(assetID)
                            val model=view.modelLoader.loadModelInstance(file.toURI().toString()) ?: error("Modellen kunde inte läsas.")
                            anchor.addChildNode(ModelNode(modelInstance=model,scaleToUnits=1.5f))
                            loaded=true;instruction.text="Där är ditt fynd. Tryck för att samla det."
                        }catch(e:Exception){instruction.text="Objektet kunde inte visas. Gå tillbaka och försök igen."}
                    }
                }
            }
        }
    }
    override fun onDestroy(){scene?.destroy();super.onDestroy()}
}
