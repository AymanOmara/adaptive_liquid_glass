package com.aymanomara.adaptive_liquid_glass

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

/**
 * The EGL context that draws decoded frames (an external OES texture) into
 * the encoder's input surface for [H264Transcoder], stamping each with its presentation time.
 */
internal class GlBridge(private val encoderSurface: Surface) {
    private val display: EGLDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
    private val context: EGLContext
    private val surface: EGLSurface
    private val texture: Int
    private val program: Int
    private val surfaceTexture: SurfaceTexture
    private val callbacks = HandlerThread("adaptive_liquid_glass_transcode").apply { start() }
    /** Released once per frame the decoder renders. */
    private val frames = Semaphore(0)
    private val matrix = FloatArray(16)
    private val quad: FloatBuffer = ByteBuffer.allocateDirect(QUAD.size * 4)
        .order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(QUAD).position(0) }

    /** Where the decoder renders. */
    val decoderSurface: Surface

    init {
        check(display != EGL14.EGL_NO_DISPLAY) { "No EGL display" }
        val version = IntArray(2)
        check(EGL14.eglInitialize(display, version, 0, version, 1)) { "eglInitialize" }
        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        val attributes = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL_RECORDABLE_ANDROID, 1,
            EGL14.EGL_NONE,
        )
        check(
            EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) &&
                count[0] > 0,
        ) { "eglChooseConfig" }
        context = EGL14.eglCreateContext(
            display, configs[0], EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
        )
        check(context != EGL14.EGL_NO_CONTEXT) { "eglCreateContext" }
        surface = EGL14.eglCreateWindowSurface(
            display, configs[0], encoderSurface, intArrayOf(EGL14.EGL_NONE), 0,
        )
        check(surface != EGL14.EGL_NO_SURFACE) { "eglCreateWindowSurface" }
        check(EGL14.eglMakeCurrent(display, surface, surface, context)) { "eglMakeCurrent" }

        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        texture = ids[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
        )
        program = link(VERTEX, FRAGMENT)
        surfaceTexture = SurfaceTexture(texture).apply {
            setOnFrameAvailableListener({ frames.release() }, Handler(callbacks.looper))
        }
        decoderSurface = Surface(surfaceTexture)
    }

    /** Waits for the frame the decoder just rendered and encodes it. */
    fun draw(presentationNs: Long) {
        check(frames.tryAcquire(FRAME_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
            "Timed out waiting for a decoded frame"
        }
        surfaceTexture.updateTexImage()
        surfaceTexture.getTransformMatrix(matrix)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
        val position = GLES20.glGetAttribLocation(program, "aPosition")
        val coord = GLES20.glGetAttribLocation(program, "aCoord")
        quad.position(0)
        GLES20.glVertexAttribPointer(position, 2, GLES20.GL_FLOAT, false, 16, quad)
        GLES20.glEnableVertexAttribArray(position)
        quad.position(2)
        GLES20.glVertexAttribPointer(coord, 2, GLES20.GL_FLOAT, false, 16, quad)
        GLES20.glEnableVertexAttribArray(coord)
        GLES20.glUniformMatrix4fv(
            GLES20.glGetUniformLocation(program, "uTexMatrix"), 1, false, matrix, 0,
        )
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        EGLExt.eglPresentationTimeANDROID(display, surface, presentationNs)
        check(EGL14.eglSwapBuffers(display, surface)) { "eglSwapBuffers" }
    }

    fun release() {
        GLES20.glDeleteProgram(program)
        GLES20.glDeleteTextures(1, intArrayOf(texture), 0)
        EGL14.eglMakeCurrent(
            display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT,
        )
        EGL14.eglDestroySurface(display, surface)
        EGL14.eglDestroyContext(display, context)
        EGL14.eglReleaseThread()
        EGL14.eglTerminate(display)
        decoderSurface.release()
        surfaceTexture.release()
        encoderSurface.release()
        callbacks.quitSafely()
    }

    private fun link(vertex: String, fragment: String): Int {
        fun compile(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, source)
            GLES20.glCompileShader(shader)
            val ok = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, ok, 0)
            check(ok[0] != 0) { "Shader: " + GLES20.glGetShaderInfoLog(shader) }
            return shader
        }
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, compile(GLES20.GL_VERTEX_SHADER, vertex))
        GLES20.glAttachShader(program, compile(GLES20.GL_FRAGMENT_SHADER, fragment))
        GLES20.glLinkProgram(program)
        val ok = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, ok, 0)
        check(ok[0] != 0) { "Program: " + GLES20.glGetProgramInfoLog(program) }
        return program
    }

    private companion object {
        const val EGL_RECORDABLE_ANDROID = 0x3142
        const val FRAME_TIMEOUT_MS = 3_000L

        /** x, y, u, v for a full-screen triangle strip. */
        val QUAD = floatArrayOf(
            -1f, -1f, 0f, 0f,
            1f, -1f, 1f, 0f,
            -1f, 1f, 0f, 1f,
            1f, 1f, 1f, 1f,
        )

        const val VERTEX = """
            uniform mat4 uTexMatrix;
            attribute vec4 aPosition;
            attribute vec4 aCoord;
            varying vec2 vCoord;
            void main() {
                gl_Position = aPosition;
                vCoord = (uTexMatrix * aCoord).xy;
            }
        """

        const val FRAGMENT = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            uniform samplerExternalOES uTexture;
            varying vec2 vCoord;
            void main() {
                gl_FragColor = texture2D(uTexture, vCoord);
            }
        """
    }
}
