package com.example.project_elara // (Change this to your package name)

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.google.ar.core.Anchor
import com.google.ar.sceneform.ux.ArFragment
import com.google.ar.sceneform.rendering.ModelRenderable
import com.google.ar.sceneform.ux.TransformableNode
import com.google.ar.sceneform.rendering.Material
import com.google.ar.sceneform.rendering.ShapeFactory
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.math.Color
import android.widget.Button
import android.view.Gravity
import android.widget.FrameLayout
import android.view.ViewGroup

class ARActivity : AppCompatActivity() {

    private var arFragment: ArFragment? = null
    private var modelPlaced = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // This layout file is required. See the next code block.
        setContentView(R.layout.activity_ar) 

        // 1. Find the ARFragment
        arFragment = supportFragmentManager.findFragmentById(R.id.ar_fragment) as ArFragment?

        // 2. Listen for a tap on a detected plane
        arFragment?.setOnTapArPlaneListener { hitResult, plane, motionEvent ->
            if (!modelPlaced) {
                // Create an anchor at the tapped spot
                val anchor = hitResult.createAnchor()
                placePet(anchor)
                modelPlaced = true // Only place one pet
            }
        }
        
        // 3. Create a "Done" button
        val doneButton = Button(this)
        doneButton.text = "Done"
        val layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.START
        ).apply { setMargins(16, 16, 0, 0) }
        doneButton.layoutParams = layoutParams

        doneButton.setOnClickListener {
            finish() // Close this activity and return to Flutter
        }
        
        // Add the button to the fragment's view
        (arFragment?.view as? FrameLayout)?.addView(doneButton)
    }

    private fun placePet(anchor: Anchor) {
        // --- THIS IS WHERE YOU LOAD YOUR "pet.glb" MODEL ---
        // For now, we will create a simple 3D cube as a placeholder.

        Material.makeOpaqueWithColor(this, Color(0.66f, 0.82f, 0.94f)) // Serene Blue
            .thenAccept { material ->
                val cube = ShapeFactory.makeCube(
                    Vector3(0.1f, 0.1f, 0.1f), 
                    Vector3.zero(), 
                    material
                )
                
                val anchorNode = com.google.ar.sceneform.AnchorNode(anchor)
                val transformableNode = TransformableNode(arFragment!!.transformationSystem)
                transformableNode.setParent(anchorNode)
                transformableNode.renderable = cube
                
                arFragment!!.arSceneView.scene.addChild(anchorNode)
                transformableNode.select()
            }
        
        // TODO: Replace the cube with:
        // ModelRenderable.builder()
        //     .setSource(this, R.raw.pet_model_glb) // put pet_model_glb in res/raw
        //     .build()
        //     .thenAccept { renderable ->
        //         ... (add renderable to node) ...
        //     }
    }
}