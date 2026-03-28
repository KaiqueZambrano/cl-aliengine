;;;; cl-aliengine.lisp - Minimal 2D engine for CL

(defpackage :cl-aliengine
  (:use :cl :sb-alien :sb-sys))

(in-package :cl-aliengine)


;;;; -------------------------------------------------------------------------
;;;; Foreign libraries
;;;; -------------------------------------------------------------------------

#+linux
(progn
  (load-shared-object "libglfw.so"  :dont-save t)
  (load-shared-object "libGL.so"    :dont-save t)
  (load-shared-object "libpng.so"   :dont-save t)
  (load-shared-object "lib/libnk_shim.so"    :dont-save t))

#+darwin
(progn
  (load-shared-object "libglfw.dylib" :dont-save t)
  (load-shared-object "/System/Library/Frameworks/OpenGL.framework/OpenGL" :dont-save t)
  (load-shared-object "libpng.dylib"  :dont-save t)
  (load-shared-object "lib/libnk_shim.dylib" :dont-save t))

#+windows
(progn
  (load-shared-object "glfw3.dll"    :dont-save t)
  (load-shared-object "opengl32.dll" :dont-save t)
  (load-shared-object "libpng16.dll" :dont-save t)
  (load-shared-object "lib/nk_shim.dll"      :dont-save t))


;;;; -------------------------------------------------------------------------
;;;; Utilities
;;;; -------------------------------------------------------------------------

(defmacro null-ptr (&optional (type '(* t)))
  "Return a typed null alien pointer.
  TYPE defaults to (* t), a generic pointer.  Pass a more specific alien type
  when the callee requires one, e.g. (null-ptr (* (* t)))."
  `(sap-alien (int-sap 0) ,type))

(declaim (inline null-ptr-p))
(defun null-ptr-p (ptr)
  "Return T if the alien pointer PTR is null (address zero)."
  (zerop (sap-int (alien-sap ptr))))


;;;; -------------------------------------------------------------------------
;;;; Global state
;;;; -------------------------------------------------------------------------

(defparameter *dt* 0.0d0
  "Delta-time in seconds for the current frame.
  Bound dynamically inside the game loop; read this from systems to get
  frame-rate-independent behaviour.")

(defparameter *window* nil
  "The active GLFW window alien pointer, or NIL when outside RUN.")

(defparameter *screen-width* 800
  "Width of the game window in pixels.  Set by RUN before the first frame.")

(defparameter *screen-height* 600
  "Height of the game window in pixels.  Set by RUN before the first frame.")

(defparameter *camera-x* 0
  "Current camera X offset in world pixels.
  Subtracted from every dst-x in DRAW-TEXTURE.  Updated each frame by the
  UPDATE-CAMERA system.  Do not set manually; use CAMERA-SNAP instead.")

(defparameter *camera-y* 0
  "Current camera Y offset in world pixels.
  Subtracted from every dst-y in DRAW-TEXTURE.  Updated each frame by the
  UPDATE-CAMERA system.  Do not set manually; use CAMERA-SNAP instead.")


;;;; -------------------------------------------------------------------------
;;;; GLFW bindings
;;;; -------------------------------------------------------------------------

(define-alien-routine ("glfwInit"               glfw-init)                int)
(define-alien-routine ("glfwTerminate"          glfw-terminate)           void)
(define-alien-routine ("glfwCreateWindow"       glfw-create-window)       (* t)
  (w int) (h int) (title c-string) (monitor (* t)) (share (* t)))
(define-alien-routine ("glfwMakeContextCurrent" glfw-make-context-current) void
  (window (* t)))
(define-alien-routine ("glfwWindowShouldClose"  glfw-window-should-close) int
  (window (* t)))
(define-alien-routine ("glfwSwapBuffers"        glfw-swap-buffers)        void
  (window (* t)))
(define-alien-routine ("glfwPollEvents"         glfw-poll-events)         void)
(define-alien-routine ("glfwGetTime"            glfw-get-time)            double)
(define-alien-routine ("glfwSwapInterval"       glfw-swap-interval)       void
  (interval int))
(define-alien-routine ("glfwGetKey"             glfw-get-key)             int
  (window (* t)) (key int))


;;;; -------------------------------------------------------------------------
;;;; OpenGL constants
;;;; -------------------------------------------------------------------------

(defconstant +color-buffer-bit+    #x00004000)
(defconstant +triangles+           #x0004)
(defconstant +float-gl+            #x1406)
(defconstant +array-buffer+        #x8892)
(defconstant +dynamic-draw+        #x88E8)
(defconstant +blend+               #x0BE2)
(defconstant +src-alpha+           #x0302)
(defconstant +one-minus-src-alpha+ #x0303)
(defconstant +texture-2d+          #x0DE1)
(defconstant +rgba+                #x1908)
(defconstant +unsigned-byte-gl+    #x1401)
(defconstant +texture-wrap-s+      #x2802)
(defconstant +texture-wrap-t+      #x2803)
(defconstant +texture-min-filter+  #x2801)
(defconstant +texture-mag-filter+  #x2800)
(defconstant +nearest+             #x2600)
(defconstant +linear+              #x2601)
(defconstant +clamp-to-edge+       #x812F)
(defconstant +texture0+            #x84C0)
(defconstant +vertex-shader+       #x8B31)
(defconstant +fragment-shader+     #x8B30)
(defconstant +compile-status+      #x8B81)


;;;; -------------------------------------------------------------------------
;;;; OpenGL bindings
;;;; -------------------------------------------------------------------------

(define-alien-routine ("glClearColor" gl-clear-color) void
  (r single-float) (g single-float) (b single-float) (a single-float))
(define-alien-routine ("glClear"      gl-clear)       void
  (mask unsigned-int))
(define-alien-routine ("glEnable"     gl-enable)      void
  (cap unsigned-int))
(define-alien-routine ("glBlendFunc"  gl-blend-func)  void
  (sfactor unsigned-int) (dfactor unsigned-int))

(define-alien-routine ("glGenTextures"    gl-gen-textures)    void
  (n int) (textures (* unsigned-int)))
(define-alien-routine ("glBindTexture"    gl-bind-texture)    void
  (target unsigned-int) (texture unsigned-int))
(define-alien-routine ("glDeleteTextures" gl-delete-textures) void
  (n int) (textures (* unsigned-int)))
(define-alien-routine ("glActiveTexture"  gl-active-texture)  void
  (texture unsigned-int))
(define-alien-routine ("glTexParameteri"  gl-tex-parameteri)  void
  (target unsigned-int) (pname unsigned-int) (param int))
(define-alien-routine ("glTexImage2D"     gl-tex-image-2d)    void
  (target unsigned-int) (level int) (internal-fmt int)
  (width int) (height int) (border int)
  (format unsigned-int) (type unsigned-int)
  (data system-area-pointer))

(define-alien-routine ("glGenBuffers"    gl-gen-buffers)     void
  (n int) (buffers (* unsigned-int)))
(define-alien-routine ("glBindBuffer"    gl-bind-buffer)     void
  (target unsigned-int) (buffer unsigned-int))
(define-alien-routine ("glBufferData"    gl-buffer-data)     void
  (target unsigned-int) (size long) (data system-area-pointer) (usage unsigned-int))
(define-alien-routine ("glBufferSubData" gl-buffer-sub-data) void
  (target unsigned-int) (offset long) (size long) (data system-area-pointer))
(define-alien-routine ("glDrawArrays"    gl-draw-arrays)     void
  (mode unsigned-int) (first int) (count int))
(define-alien-routine ("glDeleteBuffers" gl-delete-buffers)  void
  (n int) (buffers (* unsigned-int)))

(define-alien-routine ("glGenVertexArrays"         gl-gen-vertex-arrays)          void
  (n int) (arrays (* unsigned-int)))
(define-alien-routine ("glBindVertexArray"         gl-bind-vertex-array)          void
  (array unsigned-int))
(define-alien-routine ("glDeleteVertexArrays"      gl-delete-vertex-arrays)       void
  (n int) (arrays (* unsigned-int)))
(define-alien-routine ("glEnableVertexAttribArray" gl-enable-vertex-attrib-array) void
  (index unsigned-int))
(define-alien-routine ("glVertexAttribPointer"     gl-vertex-attrib-pointer)      void
  (index unsigned-int) (size int) (type unsigned-int)
  (normalized unsigned-char) (stride int) (pointer system-area-pointer))

(define-alien-routine ("glCreateShader"       gl-create-shader)        unsigned-int
  (type unsigned-int))
(define-alien-routine ("glDeleteShader"       gl-delete-shader)        void
  (shader unsigned-int))
(define-alien-routine ("glCompileShader"      gl-compile-shader)       void
  (shader unsigned-int))
(define-alien-routine ("glAttachShader"       gl-attach-shader)        void
  (prog unsigned-int) (shader unsigned-int))
(define-alien-routine ("glCreateProgram"      gl-create-program)       unsigned-int)
(define-alien-routine ("glLinkProgram"        gl-link-program)         void
  (prog unsigned-int))
(define-alien-routine ("glUseProgram"         gl-use-program)          void
  (prog unsigned-int))
(define-alien-routine ("glDeleteProgram"      gl-delete-program)       void
  (prog unsigned-int))
(define-alien-routine ("glShaderSource"       %gl-shader-source)       void
  (shader unsigned-int) (count int)
  (strings (* (* unsigned-char)))
  (lengths (* int)))
(define-alien-routine ("glGetShaderiv"        gl-get-shaderiv)         void
  (shader unsigned-int) (pname unsigned-int) (params (* int)))
(define-alien-routine ("glGetShaderInfoLog"   gl-get-shader-info-log)  void
  (shader unsigned-int) (max-len int) (length (* int)) (log (* unsigned-char)))
(define-alien-routine ("glGetUniformLocation" gl-get-uniform-location) int
  (prog unsigned-int) (name c-string))
(define-alien-routine ("glUniform1i"          gl-uniform-1i)           void
  (loc int) (v int))
(define-alien-routine ("glUniform4f"          gl-uniform-4f)           void
  (loc int) (x single-float) (y single-float) (z single-float) (w single-float))


;;;; -------------------------------------------------------------------------
;;;; libpng constants and bindings
;;;; -------------------------------------------------------------------------

(defconstant +png-transform-expand+      #x0010)
(defconstant +png-transform-strip-16+    #x0001)
(defconstant +png-transform-pack+        #x0004)
(defconstant +png-transform-gray-to-rgb+ #x2000)

(define-alien-routine ("png_create_read_struct"  png-create-read-struct)  (* t)
  (user-png-ver c-string) (error-ptr (* t)) (error-fn (* t)) (warn-fn (* t)))
(define-alien-routine ("png_create_info_struct"  png-create-info-struct)  (* t)
  (png-ptr (* t)))
(define-alien-routine ("png_destroy_read_struct" png-destroy-read-struct) void
  (png-ptr-ptr  (* (* t)))
  (info-ptr-ptr (* (* t)))
  (end-info-ptr (* (* t))))
(define-alien-routine ("png_init_io"             png-init-io)             void
  (png-ptr (* t)) (fp (* t)))
(define-alien-routine ("png_read_png"            png-read-png)            void
  (png-ptr (* t)) (info-ptr (* t)) (transforms int) (params (* t)))
(define-alien-routine ("png_get_IHDR"            png-get-ihdr)            int
  (png-ptr (* t)) (info-ptr (* t))
  (width (* unsigned-int)) (height (* unsigned-int))
  (bit-depth (* int)) (color-type (* int))
  (interlace-type (* int)) (compression-type (* int)) (filter-method (* int)))
(define-alien-routine ("png_get_rows"            png-get-rows)            (* t)
  (png-ptr (* t)) (info-ptr (* t)))
(define-alien-routine ("png_get_rowbytes"        png-get-rowbytes)        unsigned-long
  (png-ptr (* t)) (info-ptr (* t)))
(define-alien-routine ("png_get_channels"        png-get-channels)        int
  (png-ptr (* t)) (info-ptr (* t)))

(define-alien-routine ("fopen"  fopen)  (* t) (path c-string) (mode c-string))
(define-alien-routine ("fclose" fclose) int   (file (* t)))


;;;; =========================================================================
;;;; Nuklear - Global state
;;;; =========================================================================

(defparameter *nk-ctx* nil
  "Alien pointer to the nk_context.  Valid after NUI-INIT, NIL otherwise.
  Macros like WITH-UI-WINDOW and UI-* implicitly use this context; you should
  never need to pass it explicitly.")

(defparameter *nk-active* nil
  "T when the Nuklear layer is initialised and ready to accept widget calls.")


;;;; =========================================================================
;;;;  Nuklear - Constants: nk_text_alignment
;;;; =========================================================================

(defconstant +nk-text-left+     17
  "Left-justify text within its layout cell.")
(defconstant +nk-text-centered+ 18
  "Centre text within its layout cell.")
(defconstant +nk-text-right+    20
  "Right-justify text within its layout cell.")


;;;; =========================================================================
;;;;  Nuklear - Constants: nk_panel_flags  (combine with LOGIOR)
;;;; =========================================================================

(defconstant +nk-window-border+         1)
(defconstant +nk-window-movable+        2)
(defconstant +nk-window-scalable+       4)
(defconstant +nk-window-closable+       8)
(defconstant +nk-window-minimizable+   16)
(defconstant +nk-window-no-scrollbar+  32)
(defconstant +nk-window-title+         64)
(defconstant +nk-window-no-input+     512)

(defconstant +nk-window-default+
  (logior +nk-window-border+ +nk-window-movable+ +nk-window-title+)
  "Bordered, movable window with a title bar.")
(defconstant +nk-window-static+
  (logior +nk-window-border+ +nk-window-title+ +nk-window-no-scrollbar+)
  "Fixed window — suitable for HUDs that should not be dragged.")
(defconstant +nk-window-tooltip+
  (logior +nk-window-border+ +nk-window-no-scrollbar+ +nk-window-no-input+)
  "Borderless overlay with no interaction — handy for debug overlays.")


;;;; =========================================================================
;;;;  Nuklear - FFI: lifecycle
;;;; =========================================================================

(define-alien-routine ("alien_nk_init"      %nk-init)      (* t) (win (* t)))
(define-alien-routine ("alien_nk_shutdown"  %nk-shutdown)  void)
(define-alien-routine ("alien_nk_new_frame" %nk-new-frame) void)
(define-alien-routine ("alien_nk_render"    %nk-render)    void)


;;;; =========================================================================
;;;;  Nuklear - FFI: window management
;;;; =========================================================================

(define-alien-routine ("alien_nk_begin" %nk-begin) int
  (ctx (* t)) (title c-string)
  (x single-float) (y single-float)
  (w single-float) (h single-float)
  (flags unsigned-int))

(define-alien-routine ("alien_nk_end" %nk-end) void (ctx (* t)))


;;;; =========================================================================
;;;; Nuklear FFI: layout
;;;; =========================================================================

(define-alien-routine ("alien_nk_layout_row_dynamic" %nk-layout-dynamic) void
  (ctx (* t)) (height single-float) (cols int))

(define-alien-routine ("alien_nk_layout_row_static" %nk-layout-static) void
  (ctx (* t)) (height single-float) (item-width int) (cols int))

(define-alien-routine ("alien_nk_layout_space_begin" %nk-space-begin) void
  (ctx (* t)) (height single-float) (count int))

(define-alien-routine ("alien_nk_layout_space_push" %nk-space-push) void
  (ctx (* t)) (x single-float) (y single-float)
  (w single-float) (h single-float))

(define-alien-routine ("alien_nk_layout_space_end" %nk-space-end) void
  (ctx (* t)))


;;;; =========================================================================
;;;; Nuklear FFI: widgets
;;;; =========================================================================

(define-alien-routine ("alien_nk_label" %nk-label) void
  (ctx (* t)) (str c-string) (align unsigned-int))

(define-alien-routine ("alien_nk_label_colored" %nk-label-colored) void
  (ctx (* t)) (str c-string) (align unsigned-int)
  (r unsigned-char) (g unsigned-char) (b unsigned-char) (a unsigned-char))

(define-alien-routine ("alien_nk_button" %nk-button) int
  (ctx (* t)) (label c-string))

(define-alien-routine ("alien_nk_slider_float" %nk-slider-float) single-float
  (ctx (* t))
  (mn single-float) (val single-float) (mx single-float) (step single-float))

(define-alien-routine ("alien_nk_slider_int" %nk-slider-int) int
  (ctx (* t)) (mn int) (val int) (mx int) (step int))

(define-alien-routine ("alien_nk_progress" %nk-progress) unsigned-long
  (ctx (* t)) (cur unsigned-long) (mx unsigned-long) (modifiable int))

(define-alien-routine ("alien_nk_check" %nk-check) int
  (ctx (* t)) (label c-string) (active int))

(define-alien-routine ("alien_nk_option" %nk-option) int
  (ctx (* t)) (label c-string) (active int))

(define-alien-routine ("alien_nk_property_int" %nk-prop-int) int
  (ctx (* t)) (name c-string)
  (mn int) (val int) (mx int) (step int) (inc single-float))

(define-alien-routine ("alien_nk_property_float" %nk-prop-float) single-float
  (ctx (* t)) (name c-string)
  (mn single-float) (val single-float) (mx single-float)
  (step single-float) (inc single-float))

(define-alien-routine ("alien_nk_spacer"    %nk-spacer)    void (ctx (* t)))
(define-alien-routine ("alien_nk_separator" %nk-separator) void (ctx (* t)))


;;;; =========================================================================
;;;; Nuklear - FFI: style
;;;; =========================================================================

(define-alien-routine ("alien_nk_style_window_bg" %nk-style-window-bg) void
  (ctx (* t))
  (r unsigned-char) (g unsigned-char) (b unsigned-char) (a unsigned-char))

(define-alien-routine ("alien_nk_style_button_color" %nk-style-button-color) void
  (ctx (* t))
  (nr unsigned-char) (ng unsigned-char) (nb unsigned-char) (na unsigned-char)
  (hr unsigned-char) (hg unsigned-char) (hb unsigned-char) (ha unsigned-char)
  (ar unsigned-char) (ag unsigned-char) (ab unsigned-char) (aa unsigned-char))

(define-alien-routine ("alien_nk_style_text_color" %nk-style-text-color) void
  (ctx (* t))
  (r unsigned-char) (g unsigned-char) (b unsigned-char) (a unsigned-char))


;;;; =========================================================================
;;;; Nuklear - Lifecycle public
;;;; =========================================================================

(defun nui-init ()
  "Initialise the Nuklear GUI layer for *WINDOW*.
  Call this inside a scene's :on-init hook, or let RUN-WITH-UI handle it.
  Signals an error if the GLFW window is not yet open."
  (unless *window*
    (error "NUI-INIT called before the GLFW window was created.  ~
            Use RUN-WITH-UI, or call NUI-INIT from inside :on-init."))
  (let ((ctx (%nk-init *window*)))
    (when (null-ptr-p ctx)
      (error "Nuklear initialisation failed (alien_nk_init returned NULL)"))
    (setf *nk-ctx*    ctx
          *nk-active* t)))

(defun nui-shutdown ()
  "Shut down the Nuklear GUI layer and release its GPU resources.
  Called automatically by RUN-WITH-UI when the game loop exits."
  (when *nk-active*
    (%nk-shutdown)
    (setf *nk-ctx*    nil
          *nk-active* nil)))

(declaim (inline nui-new-frame nui-render))

(defun nui-new-frame ()
  "Begin a new Nuklear frame.  Called by RUN-WITH-UI before UPDATE each frame.
  If you are not using RUN-WITH-UI, call this at the very start of :on-going."
  (when *nk-active* (%nk-new-frame)))

(defun nui-render ()
  "Composite the Nuklear draw lists onto the framebuffer.
  Called by RUN-WITH-UI after FLUSH-BATCH so the UI appears above sprites.
  If you are not using RUN-WITH-UI, call this at the very end of :on-going."
  (when *nk-active* (%nk-render)))


;;;; =========================================================================
;;;; Nuklear - High-level widget macros
;;;; =========================================================================

(defmacro with-ui-window ((title &key (x 10) (y 10) (w 200) (h 300)
                                       (flags '+nk-window-default+))
                          &body body)
  "Open a Nuklear panel titled TITLE at screen position (X, Y) with size (W×H).
  BODY is evaluated only when the panel is visible (not minimised/closed).
  Always pairs BEGIN with END even when the panel is hidden.

  Keyword options:
    :x :y       — top-left screen position in pixels  (default 10, 10)
    :w :h       — panel size in pixels                (default 200, 300)
    :flags      — nk_panel_flags integer              (default +NK-WINDOW-DEFAULT+)

  Example:
    (with-ui-window (\"Settings\" :x 20 :y 20 :w 200 :h 140
                                  :flags +nk-window-static+)
      (ui-layout-row-dynamic 24 1)
      (ui-label (format nil \"Volume: ~a\" *vol*))
      (setf *vol* (ui-slider-int 0 *vol* 100)))"
  (let ((ctx (gensym "CTX")))
    `(when *nk-active*
       (let ((,ctx *nk-ctx*))
         (when (= 1 (%nk-begin ,ctx ,title
                               (float ,x 1.0f0) (float ,y 1.0f0)
                               (float ,w 1.0f0) (float ,h 1.0f0)
                               ,flags))
           ,@body)
         (%nk-end ,ctx)))))

;; Layout

(defmacro ui-layout-row-dynamic (height cols)
  "COLS equally-spaced columns of HEIGHT pixels each.
  Columns resize with the window.  Most common layout choice."
  `(%nk-layout-dynamic *nk-ctx* (float ,height 1.0f0) ,cols))

(defmacro ui-layout-row-static (height item-width cols)
  "COLS fixed-width (ITEM-WIDTH px) columns of HEIGHT pixels."
  `(%nk-layout-static *nk-ctx* (float ,height 1.0f0) ,item-width ,cols))

(defmacro with-ui-space ((height count) &body body)
  "Free-placement layout: positions up to COUNT widgets manually.
  Use UI-PLACE inside BODY to position each widget.

  Example (absolute pixel positions within the panel):
    (with-ui-space (80 2)
      (ui-place 0 0 60 20)  (ui-label \"Name\")
      (ui-place 64 0 120 20) (ui-label *player-name*))"
  `(progn
     (%nk-space-begin *nk-ctx* (float ,height 1.0f0) ,count)
     ,@body
     (%nk-space-end *nk-ctx*)))

(defmacro ui-place (x y w h)
  "Set the position for the next widget inside WITH-UI-SPACE."
  `(%nk-space-push *nk-ctx*
                   (float ,x 1.0f0) (float ,y 1.0f0)
                   (float ,w 1.0f0) (float ,h 1.0f0)))

;; Widgets

(defmacro ui-label (text &optional (align '+nk-text-left+))
  "Draw TEXT as a plain label.  ALIGN is one of the +NK-TEXT-*+ constants."
  `(%nk-label *nk-ctx* ,text ,align))

(defmacro ui-label-color (text r g b &optional (align '+nk-text-left+) (a 255))
  "Like UI-LABEL but with an explicit RGBA colour (0–255 per channel)."
  `(%nk-label-colored *nk-ctx* ,text ,align ,r ,g ,b ,a))

(defmacro ui-button (label)
  "Draw a push-button with LABEL.  Returns T on the frame it is clicked."
  `(= 1 (%nk-button *nk-ctx* ,label)))

(defmacro ui-slider-float (min val max &optional (step 0.01))
  "Float slider from MIN to MAX in steps of STEP.  Returns the new float value."
  `(%nk-slider-float *nk-ctx*
                     (float ,min 1.0f0) (float ,val 1.0f0)
                     (float ,max 1.0f0) (float ,step 1.0f0)))

(defmacro ui-slider-int (min val max &optional (step 1))
  "Integer slider from MIN to MAX in steps of STEP.  Returns the new integer."
  `(%nk-slider-int *nk-ctx* ,min ,val ,max ,step))

(defmacro ui-progress (cur max &optional (modifiable t))
  "Progress bar.  CUR and MAX are non-negative integers.
  When MODIFIABLE is T the user can drag the bar.
  Returns the (possibly updated) CUR value."
  `(%nk-progress *nk-ctx* ,cur ,max (if ,modifiable 1 0)))

(defmacro ui-check (label val)
  "Checkbox labelled LABEL.  VAL is the current boolean state.
  Returns the new boolean state (T or NIL)."
  `(= 1 (%nk-check *nk-ctx* ,label (if ,val 1 0))))

(defmacro ui-option (label active-p)
  "Radio button labelled LABEL.  Returns T when this option is selected.
  Manage exclusivity manually:
    (let ((sel (cond ((ui-option \"Easy\"   (eq *diff* :easy))   :easy)
                     ((ui-option \"Medium\" (eq *diff* :medium)) :medium)
                     ((ui-option \"Hard\"   (eq *diff* :hard))   :hard)
                     (t *diff*)))
      (setf *diff* sel))"
  `(= 1 (%nk-option *nk-ctx* ,label (if ,active-p 1 0))))

(defmacro ui-property-int (name min val max &optional (step 1) (inc 1.0))
  "Spinner property field for integers.  Returns the new integer value.
  INC-PER-PIXEL controls sensitivity when the user drags over the field."
  `(%nk-prop-int *nk-ctx* ,name ,min ,val ,max ,step (float ,inc 1.0f0)))

(defmacro ui-property-float (name min val max &optional (step 0.1) (inc 0.5))
  "Spinner property field for floats.  Returns the new float value."
  `(%nk-prop-float *nk-ctx* ,name
                   (float ,min 1.0f0) (float ,val 1.0f0)
                   (float ,max 1.0f0) (float ,step 1.0f0)
                   (float ,inc 1.0f0)))

(defmacro ui-spacer ()
  "Skip one layout cell without drawing anything."
  `(%nk-spacer *nk-ctx*))

(defmacro ui-separator ()
  "Draw a thin horizontal dividing line across the current row."
  `(%nk-separator *nk-ctx*))

;; Style helpers

(defun ui-style-window-bg (r g b &optional (a 255))
  "Set the background colour of the most recently opened panel.
  R G B A are integers in [0, 255]."
  (when *nk-active*
    (%nk-style-window-bg *nk-ctx* r g b a)))

(defun ui-style-text-color (r g b &optional (a 255))
  "Set the global text colour.  R G B A are integers in [0, 255]."
  (when *nk-active*
    (%nk-style-text-color *nk-ctx* r g b a)))

(defun ui-style-button-colors (nr ng nb
                                hr hg hb
                                ar ag ab
                                &optional (na 255) (ha 255) (aa 255))
  "Set button colours for normal / hover / active states.
  Pass RGB integer triples (0–255); alpha defaults to 255."
  (when *nk-active*
    (%nk-style-button-color *nk-ctx*
                             nr ng nb na
                             hr hg hb ha
                             ar ag ab aa)))


;;;; -------------------------------------------------------------------------
;;;; PNG loading
;;;; -------------------------------------------------------------------------

(defun %destroy-png (png-ptr info-ptr)
  "Release the libpng read and info structs pointed to by PNG-PTR and INFO-PTR.
  Either pointer may be a null-ptr; libpng handles that gracefully."
  (let ((ppng  (make-alien (* t)))
        (pinfo (make-alien (* t))))
    (unwind-protect
        (progn
          (setf (deref ppng)  png-ptr
                (deref pinfo) info-ptr)
          (png-destroy-read-struct ppng pinfo (null-ptr (* (* t)))))
      (free-alien ppng)
      (free-alien pinfo))))

(defun load-png (path)
  "Load the PNG file at PATH and return three values: (RGBA-BYTES WIDTH HEIGHT).
  RGBA-BYTES is a (simple-array (unsigned-byte 8) (*)) in row-major order with
  four channels per pixel.  RGB images are padded with alpha=255.
  Signals an error if the file is missing or libpng initialisation fails."
  (declare (optimize (speed 3) (safety 1)))
  (let ((png-ptr nil))
    (dolist (ver '("1.6.55" "1.6.0" "1.5.0"))
      (let ((p (png-create-read-struct ver (null-ptr) (null-ptr) (null-ptr))))
        (unless (null-ptr-p p)
          (setf png-ptr p)
          (return))))
    (unless png-ptr
      (error "Failed to create libpng read struct for ~s" path))
    (let ((info-ptr (png-create-info-struct png-ptr)))
      (when (null-ptr-p info-ptr)
        (%destroy-png png-ptr (null-ptr))
        (error "Failed to create libpng info struct for ~s" path))
      (let ((file (fopen path "rb")))
        (when (null-ptr-p file)
          (%destroy-png png-ptr info-ptr)
          (error "File not found: ~s" path))
        (unwind-protect
            (progn
              (png-init-io png-ptr file)
              (png-read-png png-ptr info-ptr
                            (logior +png-transform-expand+
                                    +png-transform-strip-16+
                                    +png-transform-pack+
                                    +png-transform-gray-to-rgb+)
                            (null-ptr))
              (with-alien ((aw unsigned-int) (ah unsigned-int)
                           (ab int) (ac int) (ai int) (acp int) (af int))
                (png-get-ihdr png-ptr info-ptr
                              (addr aw) (addr ah)
                              (addr ab) (addr ac)
                              (addr ai) (addr acp) (addr af))
                (let* ((w        (the fixnum aw))
                       (h        (the fixnum ah))
                       (channels (the fixnum (png-get-channels png-ptr info-ptr)))
                       (rows-sap (alien-sap (png-get-rows png-ptr info-ptr)))
                       (data     (make-array (* w h 4)
                                             :element-type '(unsigned-byte 8)
                                             :initial-element 0)))
                  (declare (type fixnum w h channels)
                           (type system-area-pointer rows-sap)
                           (type (simple-array (unsigned-byte 8) (*)) data))
                  (dotimes (y h)
                    (declare (type fixnum y))
                    (let ((row (sap-ref-sap rows-sap (* y 8))))
                      (declare (type system-area-pointer row))
                      (dotimes (x w)
                        (declare (type fixnum x))
                        (let ((dst (the fixnum (* 4 (+ (* y w) x))))
                              (src (the fixnum (* channels x))))
                          (declare (type fixnum dst src))
                          (setf (aref data dst)           (sap-ref-8 row src)
                                (aref data (+ dst 1)) (sap-ref-8 row (+ src 1))
                                (aref data (+ dst 2)) (sap-ref-8 row (+ src 2))
                                (aref data (+ dst 3)) (if (= channels 3)
                                                          255
                                                          (sap-ref-8 row (+ src 3))))))))
                  (values data w h))))
          (fclose file)
          (%destroy-png png-ptr info-ptr))))))


;;;; -------------------------------------------------------------------------
;;;; GPU texture
;;;; -------------------------------------------------------------------------

(defstruct gpu-texture
  "A texture resident on the GPU.
  ID is the OpenGL texture name.  WIDTH and HEIGHT are the pixel dimensions."
  id width height)

(defun upload-rgba-to-gl (rgba-bytes width height)
  "Upload RGBA-BYTES (a flat (unsigned-byte 8) array) to a new OpenGL texture.
  The texture is created with NEAREST filtering and CLAMP-TO-EDGE wrapping.
  Returns the integer OpenGL texture name."
  (declare (optimize (speed 3) (safety 0))
           (type (simple-array (unsigned-byte 8) (*)) rgba-bytes)
           (type fixnum width height))
  (with-alien ((tex-id unsigned-int))
    (gl-gen-textures 1 (addr tex-id))
    (gl-bind-texture +texture-2d+ tex-id)
    (gl-tex-parameteri +texture-2d+ +texture-min-filter+ +nearest+)
    (gl-tex-parameteri +texture-2d+ +texture-mag-filter+ +nearest+)
    (gl-tex-parameteri +texture-2d+ +texture-wrap-s+     +clamp-to-edge+)
    (gl-tex-parameteri +texture-2d+ +texture-wrap-t+     +clamp-to-edge+)
    (with-pinned-objects (rgba-bytes)
      (gl-tex-image-2d +texture-2d+ 0 +rgba+
                       width height 0
                       +rgba+ +unsigned-byte-gl+
                       (vector-sap rgba-bytes)))
    (the fixnum tex-id)))

(defun load-texture (path)
  "Load the PNG file at PATH and upload it to the GPU.  Returns a GPU-TEXTURE."
  (multiple-value-bind (bytes w h) (load-png path)
    (make-gpu-texture :id (upload-rgba-to-gl bytes w h) :width w :height h)))

(defun free-texture (tex)
  "Delete the GPU-TEXTURE TEX from OpenGL memory."
  (with-alien ((id unsigned-int (gpu-texture-id tex)))
    (gl-delete-textures 1 (addr id))))


;;;; -------------------------------------------------------------------------
;;;; Asset manager
;;;; -------------------------------------------------------------------------

(defparameter *asset-cache* (make-hash-table :test #'equal)
  "Hash table mapping asset path strings to loaded resources (GPU-TEXTURE etc.).")

(defun asset-texture (path)
  "Return the GPU-TEXTURE for PATH, loading and caching it on the first call.
  Subsequent calls with the same PATH return the cached instance without
  re-loading from disk."
  (or (gethash path *asset-cache*)
      (let ((tex (load-texture path)))
        (setf (gethash path *asset-cache*) tex)
        tex)))

(defun asset-free (path)
  "Unload the asset at PATH from the cache and free its GPU resources.
  Does nothing if PATH is not currently cached."
  (let ((res (gethash path *asset-cache*)))
    (when res
      (etypecase res
        (gpu-texture (free-texture res)))
      (remhash path *asset-cache*))))

(defun asset-free-all ()
  "Unload all cached assets and free all associated GPU resources.
  Called automatically by RUN on shutdown."
  (maphash (lambda (path res)
             (declare (ignore path))
             (etypecase res
               (gpu-texture (free-texture res))))
           *asset-cache*)
  (clrhash *asset-cache*))


;;;; -------------------------------------------------------------------------
;;;; Renderer — shaders
;;;; -------------------------------------------------------------------------

(defvar *sprite-shader* nil
  "The compiled OpenGL shader program used for all sprite and tile rendering.")

(defparameter *vert-src* "
#version 150 core
in vec2 aPos;
in vec2 aTexCoord;
out vec2 vTexCoord;
void main() {
    float x = (aPos.x / 400.0) - 1.0;
    float y = 1.0 - (aPos.y / 300.0);
    gl_Position = vec4(x, y, 0.0, 1.0);
    vTexCoord = aTexCoord;
}
"
  "Vertex shader source.  Converts pixel-space positions (origin top-left,
  half-extents 400x300) to normalised device coordinates.")

(defparameter *frag-src* "
#version 150 core
in vec2 vTexCoord;
out vec4 fragColor;
uniform sampler2D uTexture;
uniform vec4 uTint;
void main() {
    fragColor = texture(uTexture, vTexCoord) * uTint;
}
"
  "Fragment shader source.  Samples uTexture and multiplies by uTint.")

(defun shader-source (shader src)
  "Upload the GLSL string SRC to the already-created shader object SHADER."
  (let ((bytes (sb-ext:string-to-octets src :external-format :utf-8 :null-terminate t)))
    (with-pinned-objects (bytes)
      (with-alien ((cell unsigned-long (sap-int (vector-sap bytes))))
        (%gl-shader-source shader 1
                           (sap-alien (alien-sap (addr cell)) (* (* unsigned-char)))
                           (null-ptr (* int)))))))

(defun build-shader (type src)
  "Create, upload, and compile a shader of TYPE (+vertex-shader+ or
  +fragment-shader+) from the GLSL string SRC.
  Signals an error with the info-log on compilation failure."
  (let ((s (gl-create-shader type)))
    (shader-source s src)
    (gl-compile-shader s)
    (with-alien ((ok int 0))
      (gl-get-shaderiv s +compile-status+ (addr ok))
      (when (zerop ok)
        (with-alien ((log-buf (array unsigned-char 512)))
          (gl-get-shader-info-log s 512 (null-ptr (* int))
                                  (cast log-buf (* unsigned-char)))
          (error "Shader compilation error: ~a"
                 (cast (cast log-buf (* unsigned-char)) c-string)))))
    s))

(defun make-shader-program (vert-src frag-src)
  "Compile VERT-SRC and FRAG-SRC, link them into a program, and return the
  OpenGL program name.  The individual shader objects are deleted after linking."
  (let* ((vs   (build-shader +vertex-shader+   vert-src))
         (fs   (build-shader +fragment-shader+ frag-src))
         (prog (gl-create-program)))
    (gl-attach-shader prog vs)
    (gl-attach-shader prog fs)
    (gl-link-program prog)
    (gl-delete-shader vs)
    (gl-delete-shader fs)
    prog))


;;;; -------------------------------------------------------------------------
;;;; Renderer — texture batch
;;;; -------------------------------------------------------------------------

(defparameter *batch-max-sprites* 10000
  "Maximum number of sprites (quads) per texture per frame.
  Each quad uses 6 vertices × 4 floats = 24 floats.
  Increase this if you see sprites being silently dropped on large tilemaps.")

(defparameter *batch-group-floats* (* *batch-max-sprites* 6 4)
  "Total float capacity of a single batch group's vertex buffer.")

(defparameter *batch-vbo-bytes* (* *batch-group-floats* 4)
  "Byte size of the VBO allocated for one batch group.")

(defstruct batch-group
  "Holds the CPU-side vertex data for all quads sharing a single texture.
  FLOATS is the interleaved (x y u v) float array; COUNT is the next free float index."
  (floats (make-array *batch-group-floats* :element-type 'single-float :initial-element 0.0f0)
          :type (simple-array single-float (*)))
  (count  0 :type fixnum))

(defparameter *batch-groups* (make-hash-table :test #'eql)
  "Hash table mapping integer OpenGL texture IDs to their BATCH-GROUP.")

(defvar *batch-vao* nil "The VAO shared by all batch groups.")
(defvar *batch-vbo* nil "The VBO shared by all batch groups (re-uploaded each flush).")

(defun make-batch-renderer ()
  "Allocate the shared VAO and VBO for the batch renderer.
  Returns two values: (VAO VBO).  Called once by RUN during startup."
  (with-alien ((pvao unsigned-int) (pvbo unsigned-int))
    (gl-gen-vertex-arrays 1 (addr pvao))
    (gl-gen-buffers       1 (addr pvbo))
    (let ((vao pvao) (vbo pvbo))
      (gl-bind-vertex-array vao)
      (gl-bind-buffer +array-buffer+ vbo)
      (gl-buffer-data +array-buffer+ *batch-vbo-bytes* (int-sap 0) +dynamic-draw+)
      (let ((stride 16))
        (gl-vertex-attrib-pointer 0 2 +float-gl+ 0 stride (int-sap 0))
        (gl-enable-vertex-attrib-array 0)
        (gl-vertex-attrib-pointer 1 2 +float-gl+ 0 stride (int-sap 8))
        (gl-enable-vertex-attrib-array 1))
      (gl-bind-vertex-array 0)
      (values vao vbo))))

(declaim (inline %batch-group-for))
(defun %batch-group-for (tex-id)
  "Return the BATCH-GROUP for TEX-ID, creating a new one if necessary."
  (declare (type fixnum tex-id))
  (or (gethash tex-id *batch-groups*)
      (let ((g (make-batch-group)))
        (setf (gethash tex-id *batch-groups*) g)
        g)))

(defun draw-texture (tex src-x src-y src-w src-h
                         dst-x dst-y dst-w dst-h
                         &optional (flip-x nil) (flip-y nil))
  "Queue a textured quad for rendering during the next FLUSH-BATCH call.

  TEX            — a GPU-TEXTURE.
  SRC-X SRC-Y    — top-left pixel of the source region within TEX.
  SRC-W SRC-H    — pixel dimensions of the source region.
  DST-X DST-Y    — top-left world-space pixel of the destination quad.
                   *CAMERA-X*/*CAMERA-Y* are subtracted automatically.
  DST-W DST-H    — pixel dimensions of the destination quad.
  FLIP-X FLIP-Y  — when T, mirror the quad on that axis.

  This function writes directly into the CPU vertex buffer; no GL calls are
  made until FLUSH-BATCH."
  (declare (optimize (speed 3) (safety 0) (debug 0))
           (type fixnum src-x src-y src-w src-h dst-x dst-y dst-w dst-h)
           (type boolean flip-x flip-y))
  (let* ((tw      (float (gpu-texture-width  tex) 1.0f0))
         (th      (float (gpu-texture-height tex) 1.0f0))
         (u-left  (/ (float src-x 1.0f0) tw))
         (u-right (/ (float (the fixnum (+ src-x src-w)) 1.0f0) tw))
         (v-top   (/ (float src-y 1.0f0) th))
         (v-bot   (/ (float (the fixnum (+ src-y src-h)) 1.0f0) th))
         (u0 (if flip-x u-right u-left))
         (u1 (if flip-x u-left  u-right))
         (v0 (if flip-y v-bot   v-top))
         (v1 (if flip-y v-top   v-bot))
         (x0 (float (the fixnum (- dst-x *camera-x*)) 1.0f0))
         (y0 (float (the fixnum (- dst-y *camera-y*)) 1.0f0))
         (x1 (float (the fixnum (- (+ dst-x dst-w) *camera-x*)) 1.0f0))
         (y1 (float (the fixnum (- (+ dst-y dst-h) *camera-y*)) 1.0f0))
         (g  (%batch-group-for (gpu-texture-id tex)))
         (arr (batch-group-floats g))
         (i   (batch-group-count g)))
    (declare (type single-float tw th u0 u1 v0 v1 x0 y0 x1 y1)
             (type (simple-array single-float (*)) arr)
             (type fixnum i))
    (setf (aref arr i)        x0  (aref arr (+ i  1)) y0
          (aref arr (+ i  2)) u0  (aref arr (+ i  3)) v0
          (aref arr (+ i  4)) x1  (aref arr (+ i  5)) y0
          (aref arr (+ i  6)) u1  (aref arr (+ i  7)) v0
          (aref arr (+ i  8)) x1  (aref arr (+ i  9)) y1
          (aref arr (+ i 10)) u1  (aref arr (+ i 11)) v1)
    (setf (aref arr (+ i 12)) x0  (aref arr (+ i 13)) y0
          (aref arr (+ i 14)) u0  (aref arr (+ i 15)) v0
          (aref arr (+ i 16)) x1  (aref arr (+ i 17)) y1
          (aref arr (+ i 18)) u1  (aref arr (+ i 19)) v1
          (aref arr (+ i 20)) x0  (aref arr (+ i 21)) y1
          (aref arr (+ i 22)) u0  (aref arr (+ i 23)) v1)
    (setf (batch-group-count g) (the fixnum (+ i 24)))))

(defun flush-batch ()
  "Upload and draw all queued quads, then reset every batch group's counter.
  Called once per frame by RUN after UPDATE returns.  Issues one
  glBufferSubData + glDrawArrays call per texture that has pending quads."
  (declare (optimize (speed 3) (safety 0)))
  (gl-bind-vertex-array *batch-vao*)
  (gl-bind-buffer +array-buffer+ *batch-vbo*)
  (maphash
   (lambda (tex-id g)
     (declare (type fixnum tex-id)
              (type batch-group g))
     (let ((n (batch-group-count g)))
       (declare (type fixnum n))
       (when (> n 0)
         (let ((arr (batch-group-floats g)))
           (declare (type (simple-array single-float (*)) arr))
           (with-pinned-objects (arr)
             (gl-buffer-sub-data +array-buffer+ 0 (the fixnum (* n 4)) (vector-sap arr))))
         (gl-active-texture +texture0+)
         (gl-bind-texture +texture-2d+ tex-id)
         (gl-draw-arrays +triangles+ 0 (the fixnum (ash n -2)))
         (setf (batch-group-count g) 0))))
   *batch-groups*)
  (gl-bind-vertex-array 0))


;;;; -------------------------------------------------------------------------
;;;; ECS — state
;;;; -------------------------------------------------------------------------

(defparameter *entities*       '() "List of all live entities.  Each entity is (id . components).")
(defparameter *components*     '() "Registry of declared components as (name . fields) pairs.")
(defparameter *systems*        '() "List of system plists registered via DEFSYSTEM.")
(defparameter *scenes*         '() "List of scene plists registered via DEFSCENE.")
(defparameter *next-entity-id* 0   "Monotonically increasing counter used by MAKE-ENTITY-ID.")
(defparameter *current-scene*  nil "The scene plist currently being executed, or NIL.")


;;;; -------------------------------------------------------------------------
;;;; ECS — components
;;;; -------------------------------------------------------------------------

(defmacro defcomponent (name fields)
  "Declare a component named NAME with the given FIELDS list.
  Components are stored as plists on each entity; field names become keywords.
  Example:
    (defcomponent transform (x y))
    ;; fields accessed as transform.x and transform.y inside DEFSYSTEM bodies."
  `(push (cons ',name ',fields) *components*))


;;;; -------------------------------------------------------------------------
;;;; ECS — entities
;;;; -------------------------------------------------------------------------

(defun make-entity-id ()
  "Return a unique integer ID for a new entity."
  (incf *next-entity-id*))

(defun add-component (entity comp-name data)
  "Attach component COMP-NAME with plist DATA to ENTITY.
  DATA should be a list of alternating keyword/value pairs matching the
  field declaration from DEFCOMPONENT."
  (push (cons comp-name data) (cdr entity)))

(defmacro spawn (&rest components)
  "Create a new entity, attach the given COMPONENTS, register it, and return it.
  Each element of COMPONENTS is a list of the form (component-name field-value ...).
  Example:
    (spawn (transform :x 0 :y 0)
           (sprite :texture tex :src-x 0 :src-y 0 :src-w 16 :src-h 16 :scale 2 :flip-x nil))"
  (let ((entity-sym (gensym "ENTITY")))
    `(let ((,entity-sym (cons (make-entity-id) '())))
       ,@(mapcar (lambda (comp)
                   (destructuring-bind (name &rest args) comp
                     `(add-component ,entity-sym ',name (list ,@args))))
                 components)
       (push ,entity-sym *entities*)
       ,entity-sym)))


;;;; -------------------------------------------------------------------------
;;;; ECS — systems
;;;; -------------------------------------------------------------------------

(defun %expand-dots (form with-list)
  "Walk FORM replacing dot-notation symbols (e.g. transform.x) with
  (getf transform :x) when the prefix matches a name in WITH-LIST.
  Used internally by DEFSYSTEM to enable the compact field-access syntax."
  (cond
    ((and (symbolp form) (not (keywordp form)))
     (let* ((name    (symbol-name form))
            (dot-pos (position #\. name)))
       (if dot-pos
           (let ((comp  (intern (subseq name 0 dot-pos) *package*))
                 (field (intern (subseq name (1+ dot-pos)) :keyword)))
             (if (member comp with-list :test #'string=)
                 `(getf ,comp ,field)
                 form))
           form)))
    ((atom form) form)
    (t (mapcar (lambda (x) (%expand-dots x with-list)) form))))

(defun get-component (entity name)
  "Return the component plist for NAME on ENTITY, or NIL if absent."
  (cdr (assoc name (cdr entity))))

(defmacro query ((&key with without) &body body)
  "Itera sobre *ENTITIES* e executa BODY para cada entidade que:
   - contém todos os componentes listados em WITH (opcional)
   - não contém nenhum dos componentes listados em WITHOUT (opcional)

   Dentro de BODY, estão disponíveis:
   - ENTITY-ID (o número da entidade)
   - variáveis com o nome de cada componente em WITH (ex: transform, velocity)
   - acesso a campos via ponto: transform.x, velocity.vx, etc.

   Exemplo:
     (query (:with (transform velocity) :without (dead))
       (format t \"~a: pos=~a,~a vel=~a,~a~%\" entity-id
               transform.x transform.y
               velocity.vx velocity.vy))"
  (let* ((with-list   (or with '()))
         (without-list (or without '()))
         (expanded-body
           (mapcar (lambda (form) (%expand-dots form with-list)) body)))
    `(dolist (entity *entities*)
       (when (and ,@(mapcar (lambda (c) `(entity-has entity ',c)) with-list)
                  ,@(mapcar (lambda (c) `(entity-lacks entity ',c)) without-list))
         (let ((entity-id (car entity))
               ,@(mapcar (lambda (c) `(,c (get-component entity ',c))) with-list))
           ,@expanded-body)))))

(defmacro defsystem (name &rest args)
  "Define a system named NAME that runs its body for every matching entity.

  Syntax:
    (defsystem my-system :with (comp-a comp-b) :without (comp-c)
      body-form...)

  :WITH    — list of required component names.  Each becomes a local variable
             bound to the component plist.  Dot-notation (e.g. comp-a.field)
             expands to (getf comp-a :field) inside the body.
  :WITHOUT — list of component names that must be absent.  Useful for tags
             like (dead) to exclude entities from a system.
  ENTITY-ID is also bound implicitly inside the body."
  (let ((remaining args)
        (with nil)
        (without nil))
    (loop while (and remaining (keywordp (car remaining)))
          do (let ((k (pop remaining))
                   (v (pop remaining)))
               (case k
                 (:with    (setf with v))
                 (:without (setf without v)))))
    (let* ((body remaining)
           (expanded-body (mapcar (lambda (form) (%expand-dots form with)) body)))
      `(push (list :name    ',name
                   :with    ',with
                   :without ',without
                   :fn      (lambda (entity)
                              (let ((entity-id (car entity))
                                    ,@(mapcar (lambda (c) `(,c (get-component entity ',c))) with))
                                ,@expanded-body)))
             *systems*))))

(defun entity-has (entity comp)
  "Return the component cons cell for COMP on ENTITY, or NIL if absent."
  (assoc comp (cdr entity)))

(defun entity-lacks (entity comp)
  "Return T if ENTITY does not have component COMP."
  (not (entity-has entity comp)))

(defun run-system (system)
  "Execute SYSTEM against every entity that satisfies its :with/:without filters."
  (destructuring-bind (&key with without fn &allow-other-keys) system
    (dolist (e *entities*)
      (when (and (every (lambda (c) (entity-has  e c)) with)
                 (every (lambda (c) (entity-lacks e c)) without))
        (funcall fn e)))))

(defun find-system (name)
  "Return the system plist for NAME, or NIL if not found."
  (find name *systems* :key (lambda (s) (getf s :name))))

(defmacro syscall (name)
  "Run the system named NAME against all matching entities.
  Expands to (run-system (find-system 'name)).
  Use this inside DEFSCENE :on-going bodies to drive your game logic."
  `(run-system (find-system ',name)))


;;;; -------------------------------------------------------------------------
;;;; Scenes
;;;; -------------------------------------------------------------------------

(defun %parse-scene-body (body)
  "Partition the flat BODY list into four sublists by :on-init/:on-enter/
  :on-going/:on-exit keyword markers.
  Returns a list of four sublists: (init enter going exit)."
  (let ((on-init '()) (on-enter '()) (on-going '()) (on-exit '()) (current nil))
    (dolist (item body)
      (cond
        ((eq item :on-init)  (setf current :init))
        ((eq item :on-enter) (setf current :enter))
        ((eq item :on-going) (setf current :going))
        ((eq item :on-exit)  (setf current :exit))
        (t (case current
             (:init  (push item on-init))
             (:enter (push item on-enter))
             (:going (push item on-going))
             (:exit  (push item on-exit))))))
    (list (nreverse on-init)
          (nreverse on-enter)
          (nreverse on-going)
          (nreverse on-exit))))

(defmacro defscene (name &rest body)
  "Declare a scene named NAME with optional lifecycle hooks.

  Syntax:
    (defscene my-scene
      :on-init  forms-run-once-on-first-enter...
      :on-enter forms-run-each-time-scene-is-entered...
      :on-going forms-run-every-frame...
      :on-exit  forms-run-when-leaving-the-scene...)

  All four hooks are optional.  :on-init runs only the first time the scene
  is entered; :on-enter runs on every subsequent entry.  Call SWITCH-SCENE
  to transition between scenes at runtime."
  (destructuring-bind (on-init on-enter on-going on-exit) (%parse-scene-body body)
    `(push (list :name        ',name
                 :initialized nil
                 :on-init     (lambda () ,@on-init)
                 :on-enter    (lambda () ,@on-enter)
                 :on-going    (lambda () ,@on-going)
                 :on-exit     (lambda () ,@on-exit))
           *scenes*)))

(defun find-scene (name)
  "Return the scene plist for NAME, or NIL if not found."
  (find name *scenes* :key (lambda (s) (getf s :name))))

(defun switch-scene (name)
  "Transition to the scene named NAME.
  Calls :on-exit on the current scene (if any), then :on-init (first visit)
  or :on-enter (subsequent visits) on the new scene."
  (when *current-scene*
    (funcall (getf *current-scene* :on-exit)))
  (let ((new-scene (find-scene name)))
    (if (getf new-scene :initialized)
        (funcall (getf new-scene :on-enter))
        (progn
          (funcall (getf new-scene :on-init))
          (setf (getf new-scene :initialized) t)))
    (setf *current-scene* new-scene)))

(defun update ()
  "Invoke the :on-going hook of *CURRENT-SCENE*.  Called once per frame by RUN."
  (when *current-scene*
    (funcall (getf *current-scene* :on-going))))


;;;; -------------------------------------------------------------------------
;;;; Input
;;;; -------------------------------------------------------------------------

(defun key-down-p (key)
  "Return T if the GLFW key code KEY is currently held down.
  Use GLFW key constants (integers) directly, e.g. 262 = GLFW_KEY_RIGHT."
  (= 1 (glfw-get-key *window* key)))



;;;; -------------------------------------------------------------------------
;;;; Built-in components
;;;; -------------------------------------------------------------------------

(defcomponent transform (x y))

(defcomponent sprite (texture src-x src-y src-w src-h scale :flip-x))

(defcomponent animator (animations current current-time current-frame playing last-animation))

(defcomponent ui-panel (title x y w h flags visible fn))


;;;; -------------------------------------------------------------------------
;;;; Built-in systems
;;;; -------------------------------------------------------------------------

(defsystem animate :with (sprite animator)
  "Advance the animator and update the sprite's source rectangle each frame.
  Handles animation switching, looping, and one-shot playback.
  TEXTURE is swapped on the sprite if the animation plist provides one."
  (let* ((current-anim animator.current)
         (anim-data    (cdr (assoc current-anim animator.animations))))
    (when anim-data
      (unless (eq current-anim animator.last-animation)
        (setf animator.current-time 0.0
              animator.current-frame 0
              animator.last-animation current-anim)
        (let ((new-tex (getf anim-data :texture)))
          (when new-tex
            (setf sprite.texture new-tex))))

      (let* ((dt *dt*)
             (frame-time (getf anim-data :frame-time))
             (loop (getf anim-data :loop))
             (playing animator.playing)
             (frames (getf anim-data :frames))
             (current-time animator.current-time)
             (current-frame animator.current-frame)
             (frame-width sprite.src-w)
             (frame-height sprite.src-h)
             (texture sprite.texture))

        (when playing
          (setf current-time (+ current-time dt))
          (let ((total-time (* frame-time (length frames))))
            (if loop
                (setf current-time (mod current-time total-time))
                (when (> current-time total-time)
                  (setf current-time total-time
                        playing nil))))
          (setf current-frame (floor current-time frame-time))
          (setf animator.current-time current-time
                animator.current-frame current-frame
                animator.playing playing))

        (let* ((cols (floor (gpu-texture-width texture) frame-width))
               (frame-x (mod current-frame cols))
               (frame-y (floor current-frame cols)))
          (setf sprite.src-x (* frame-x frame-width)
                sprite.src-y (* frame-y frame-height)))))))

(defsystem render-sprites :with (transform sprite)
  "Enqueue a draw call for every entity with both TRANSFORM and SPRITE.
  Scale is applied uniformly to SRC-W and SRC-H.  Call this after ANIMATE
  so the source rectangle reflects the current frame."
  (draw-texture sprite.texture
                sprite.src-x sprite.src-y
                sprite.src-w sprite.src-h
                transform.x transform.y
                (* sprite.src-w sprite.scale)
                (* sprite.src-h sprite.scale)
                sprite.flip-x))

(defsystem render-ui :with (ui-panel)
  "Draw all visible UI panels for every entity that has a UI-PANEL component.
  Always call this as the LAST system in :on-going when using RUN-WITH-UI,
  so the panels composite on top of the sprite batch.

  Example scene:
    (defscene game
      :on-going
      (syscall update-camera)
      (syscall animate)
      (syscall render-sprites)
      (syscall render-tilemaps)
      (syscall render-ui))          ; ← must be last"
  (when (and *nk-active* ui-panel.visible)
    (when (= 1 (%nk-begin *nk-ctx*
                          ui-panel.title
                          (float ui-panel.x 1.0f0)
                          (float ui-panel.y 1.0f0)
                          (float ui-panel.w 1.0f0)
                          (float ui-panel.h 1.0f0)
                          ui-panel.flags))
      (funcall ui-panel.fn))
    (%nk-end *nk-ctx*)))


;;;; -------------------------------------------------------------------------
;;;; Animation helper macro
;;;; -------------------------------------------------------------------------

(defmacro make-animations (&rest specs)
  "Build an animation alist suitable for the ANIMATOR component's :animations field.

  Each SPEC has the form (name &rest plist-args), where NAME becomes a keyword
  and PLIST-ARGS are passed through verbatim.  Common plist keys:
    :texture    — GPU-TEXTURE to switch to when this animation starts (optional).
    :frames     — list of frame indices into the sprite sheet row.
    :frame-time — duration in seconds per frame.
    :loop       — T for looping, NIL for one-shot.

  Example:
    (make-animations
      (idle :texture tex-idle :frames '(0 1 2 3) :frame-time 0.12 :loop t)
      (run  :texture tex-run  :frames '(0 1 2 3 4 5) :frame-time 0.08 :loop t))"
  `(list ,@(mapcar (lambda (spec)
                     (destructuring-bind (name &rest args) spec
                       `(list ,(intern (string name) :keyword) ,@args)))
                   specs)))


;;;; -------------------------------------------------------------------------
;;;; JSON parser (zero dependencies, Tiled map support)
;;;; -------------------------------------------------------------------------

(defun %json-read-file (path)
  "Read the entire UTF-8 file at PATH into a string and return it."
  (with-open-file (s path :direction :input :external-format :utf-8)
    (let* ((buf (make-string (+ (file-length s) 1)))
           (n   (read-sequence buf s)))
      (subseq buf 0 n))))

(defun %json-skip-ws (str pos)
  "Advance the mutable position cursor POS past any whitespace in STR.
  POS is a cons cell (index . nil) used as a mutable integer reference."
  (loop while (and (< (car pos) (length str))
                   (member (char str (car pos))
                           '(#\Space #\Tab #\Newline #\Return #\Page)))
        do (incf (car pos))))

(defun %json-expect-char (str pos ch)
  "Skip whitespace then assert that the character at POS in STR equals CH.
  Advances POS past CH on success; signals an error on mismatch."
  (%json-skip-ws str pos)
  (unless (char= (char str (car pos)) ch)
    (error "JSON: expected '~a' at position ~a, found '~a'"
           ch (car pos) (char str (car pos))))
  (incf (car pos)))

(defun %json-parse-string (str pos)
  "Parse a JSON string starting at POS in STR.  Returns the Lisp string value
  and advances POS past the closing double-quote.  Handles standard JSON
  escape sequences (\\n \\t \\r \\\\ \\\" \\/)."
  (%json-expect-char str pos #\")
  (let ((out (make-string-output-stream)))
    (loop
      (when (>= (car pos) (length str))
        (error "JSON: unexpected end of input inside string"))
      (let ((c (char str (car pos))))
        (incf (car pos))
        (cond
          ((char= c #\") (return (get-output-stream-string out)))
          ((char= c #\\)
           (let ((e (char str (car pos))))
             (incf (car pos))
             (write-char (case e
                           (#\n #\Newline) (#\t #\Tab)
                           (#\r #\Return)  (#\\ #\\)
                           (#\"  #\")      (#\/  #\/)
                           (t e))
                         out)))
          (t (write-char c out)))))))

(defun %json-parse-number (str pos)
  "Parse a JSON number starting at POS in STR.
  Uses a fast integer path for whole numbers (the common case for tile GIDs)
  and falls back to READ-FROM-STRING for decimals and scientific notation."
  (let ((start (car pos)) (neg nil))
    (when (char= (char str start) #\-)
      (setf neg t)
      (incf (car pos)))
    (let ((n 0))
      (loop while (and (< (car pos) (length str))
                       (digit-char-p (char str (car pos))))
            do (setf n (+ (* n 10) (digit-char-p (char str (car pos)))))
               (incf (car pos)))
      (if (and (< (car pos) (length str))
               (find (char str (car pos)) ".eE" :test #'char=))
          (progn
            (loop while (and (< (car pos) (length str))
                             (find (char str (car pos)) "0123456789.eE+-" :test #'char=))
                  do (incf (car pos)))
            (read-from-string (subseq str start (car pos))))
          (if neg (- n) n)))))

(defun %json-parse-array (str pos)
  "Parse a JSON array starting at POS in STR.
  Returns a Lisp list of parsed values and advances POS past the closing bracket."
  (%json-expect-char str pos #\[)
  (%json-skip-ws str pos)
  (if (char= (char str (car pos)) #\])
      (progn (incf (car pos)) '())
      (let ((items '()))
        (loop
          (push (%json-parse-value str pos) items)
          (%json-skip-ws str pos)
          (case (char str (car pos))
            (#\, (incf (car pos)))
            (#\] (incf (car pos)) (return))
            (t   (error "JSON: expected ',' or ']' at position ~a" (car pos)))))
        (nreverse items))))

(defun %json-parse-object (str pos)
  "Parse a JSON object starting at POS in STR.
  Returns an alist of (string . value) pairs and advances POS past the closing brace."
  (%json-expect-char str pos #\{)
  (%json-skip-ws str pos)
  (if (char= (char str (car pos)) #\})
      (progn (incf (car pos)) '())
      (let ((pairs '()))
        (loop
          (%json-skip-ws str pos)
          (let ((k (%json-parse-string str pos)))
            (%json-expect-char str pos #\:)
            (push (cons k (%json-parse-value str pos)) pairs))
          (%json-skip-ws str pos)
          (case (char str (car pos))
            (#\, (incf (car pos)))
            (#\} (incf (car pos)) (return))
            (t   (error "JSON: expected ',' or '}' at position ~a" (car pos)))))
        (nreverse pairs))))

(defun %json-parse-value (str pos)
  "Dispatch to the appropriate parser for the JSON value at POS in STR.
  Handles strings, objects, arrays, numbers, true, false, and null."
  (%json-skip-ws str pos)
  (when (>= (car pos) (length str))
    (error "JSON: unexpected end of input"))
  (let ((c (char str (car pos))))
    (case c
      (#\" (%json-parse-string str pos))
      (#\{ (%json-parse-object str pos))
      (#\[ (%json-parse-array  str pos))
      (t
       (cond
         ((or (digit-char-p c) (char= c #\-))
          (%json-parse-number str pos))
         ((and (<= (+ (car pos) 4) (length str))
               (string= str "true" :start1 (car pos) :end1 (+ (car pos) 4)))
          (incf (car pos) 4) t)
         ((and (<= (+ (car pos) 5) (length str))
               (string= str "false" :start1 (car pos) :end1 (+ (car pos) 5)))
          (incf (car pos) 5) nil)
         ((and (<= (+ (car pos) 4) (length str))
               (string= str "null" :start1 (car pos) :end1 (+ (car pos) 4)))
          (incf (car pos) 4) :null)
         (t (error "JSON: unexpected character '~a' at position ~a" c (car pos))))))))

(defun json-parse (str)
  "Parse the JSON string STR and return the corresponding Lisp value.
  Mapping: object → alist, array → list, string → string,
           integer → integer, float → float, true → T, false → NIL, null → :NULL."
  (%json-parse-value str (cons 0 nil)))

(defun json-get (obj key)
  "Look up KEY (a string) in the JSON object OBJ (an alist).
  Returns the associated value, or NIL if KEY is absent."
  (cdr (assoc key obj :test #'equal)))


;;;; -------------------------------------------------------------------------
;;;; Tiled map support — tileset
;;;; -------------------------------------------------------------------------

(defstruct tilemap-tileset
  "Metadata for a Tiled tileset, paired with its GPU texture.
  TEXTURE  — GPU-TEXTURE of the sprite sheet image.
  FIRSTGID — the first global tile ID that belongs to this tileset.
  COLUMNS  — number of tile columns in the sprite sheet.
  TILE-W   — width of one tile in pixels.
  TILE-H   — height of one tile in pixels."
  texture firstgid columns tile-w tile-h)

(defun %tiled-dir (map-path)
  "Return the directory portion of MAP-PATH as a namestring with a trailing separator."
  (namestring
   (make-pathname :defaults (pathname map-path) :name nil :type nil)))

(defun %tiled-resolve (rel base-dir)
  "Resolve the relative path REL against BASE-DIR and return a namestring.
  Used to locate tileset images and external .tsj files relative to the map."
  (namestring (merge-pathnames rel (pathname base-dir))))

(defun %tiled-load-tileset-json (ts-json dir firstgid)
  "Construct a TILEMAP-TILESET from a parsed tileset JSON node TS-JSON.
  DIR is the base directory for resolving the image path.
  FIRSTGID is the global tile ID offset read from the map's tileset reference."
  (let* ((tw   (json-get ts-json "tilewidth"))
         (th   (json-get ts-json "tileheight"))
         (cols (json-get ts-json "columns"))
         (img  (json-get ts-json "image")))
    (unless img  (error "Tileset missing required field 'image'"))
    (unless cols (error "Tileset missing required field 'columns'"))
    (make-tilemap-tileset
     :texture  (asset-texture (%tiled-resolve img dir))
     :firstgid firstgid
     :columns  cols
     :tile-w   (or tw (error "Tileset missing required field 'tilewidth'"))
     :tile-h   (or th (error "Tileset missing required field 'tileheight'")))))


;;;; -------------------------------------------------------------------------
;;;; Tiled map support — layer parsing
;;;; -------------------------------------------------------------------------

(defun %tiled-parse-object (obj-json)
  "Convert a Tiled object JSON node to a plist with keys:
  :id :name :type :x :y :width :height :properties.
  Supports both the legacy 'type' field and the newer 'class' field."
  (list :id         (or (json-get obj-json "id")     0)
        :name       (or (json-get obj-json "name")   "")
        :type       (or (json-get obj-json "type")
                        (json-get obj-json "class")
                        "")
        :x          (round (or (json-get obj-json "x")      0))
        :y          (round (or (json-get obj-json "y")      0))
        :width      (round (or (json-get obj-json "width")  0))
        :height     (round (or (json-get obj-json "height") 0))
        :properties (json-get obj-json "properties")))

(defun %tiled-parse-layer (layer-json)
  "Convert a Tiled layer JSON node to a plist.

  Tile layer   → (:type :tile   :name … :visible … :width … :height … :data fixnum-vector)
  Object layer → (:type :object :name … :visible … :objects list-of-plists)
  Other        → (:type :unknown :name … :visible …)"
  (let* ((type    (json-get layer-json "type"))
         (name    (or (json-get layer-json "name") ""))
         (vis-raw (json-get layer-json "visible"))
         (visible (if (eq vis-raw :null) t (not (null vis-raw)))))
    (cond
      ((equal type "tilelayer")
       (let* ((raw  (json-get layer-json "data"))
              (data (make-array (length raw)
                                :element-type 'fixnum
                                :initial-contents (mapcar #'floor raw))))
         (list :type    :tile
               :name    name
               :visible visible
               :width   (json-get layer-json "width")
               :height  (json-get layer-json "height")
               :data    data)))
      ((equal type "objectgroup")
       (list :type    :object
             :name    name
             :visible visible
             :objects (mapcar #'%tiled-parse-object
                              (or (json-get layer-json "objects") '()))))
      (t
       (list :type :unknown :name name :visible visible)))))


;;;; -------------------------------------------------------------------------
;;;; Tiled map support — map loader
;;;; -------------------------------------------------------------------------

(defun load-tilemap (path)
  "Load a Tiled JSON map file (.tmj / .json) and return six values:
    TILESET  WIDTH  HEIGHT  TILE-WIDTH  TILE-HEIGHT  LAYERS

  TILESET — a TILEMAP-TILESET (texture + column/GID metadata).
  LAYERS  — a list of layer plists (tile layers and object layers).

  External tileset files (.tsj) are resolved relative to the map file.
  Only the first tileset entry in the map is loaded.

  Typical usage:
    (multiple-value-bind (ts w h tw th ly) (load-tilemap \"assets/level1.tmj\")
      (spawn (transform :x 0 :y 0)
             (tilemap :tileset ts :width w :height h
                      :tile-width tw :tile-height th :layers ly)))"
  (let* ((dir      (%tiled-dir path))
         (json     (json-parse (%json-read-file path)))
         (mw       (json-get json "width"))
         (mh       (json-get json "height"))
         (tw       (json-get json "tilewidth"))
         (th       (json-get json "tileheight"))
         (ts-ref   (first (json-get json "tilesets")))
         (firstgid (or (json-get ts-ref "firstgid") 1))
         (tileset
           (let ((src (json-get ts-ref "source")))
             (if src
                 (let* ((tsj-path (%tiled-resolve src dir))
                        (tsj      (json-parse (%json-read-file tsj-path))))
                   (%tiled-load-tileset-json tsj dir firstgid))
                 (%tiled-load-tileset-json ts-ref dir firstgid))))
         (layers
           (mapcar #'%tiled-parse-layer
                   (or (json-get json "layers") '()))))
    (values tileset mw mh tw th layers)))


;;;; -------------------------------------------------------------------------
;;;; Tiled map support — component and system
;;;; -------------------------------------------------------------------------

(defcomponent tilemap (tileset width height tile-width tile-height layers))

(defsystem render-tilemaps :with (transform tilemap)
  "Draw all visible tile layers of every entity that has TRANSFORM and TILEMAP.
  The transform's X/Y is used as the world-space origin of the map.
  Call this before RENDER-SPRITES so the map renders behind sprites."
  (let* ((ts  tilemap.tileset)
         (tw  tilemap.tile-width)
         (th  tilemap.tile-height)
         (ox  transform.x)
         (oy  transform.y)
         (tex (tilemap-tileset-texture  ts))
         (fg  (tilemap-tileset-firstgid ts))
         (col (tilemap-tileset-columns  ts)))
    (dolist (layer tilemap.layers)
      (when (and (eq  (getf layer :type)    :tile)
                 (not (null (getf layer :visible t))))
        (let* ((data (getf layer :data))
               (lw   (getf layer :width))
               (n    (length data)))
          (dotimes (i n)
            (let ((gid (aref data i)))
              (unless (zerop gid)
                (let* ((lid (- gid fg))
                       (tc  (mod   lid col))
                       (tr  (floor lid col))
                       (sx  (* tc tw))
                       (sy  (* tr th))
                       (mx  (mod   i lw))
                       (my  (floor i lw))
                       (dx  (+ ox (* mx tw)))
                       (dy  (+ oy (* my th))))
                  (draw-texture tex sx sy tw th dx dy tw th))))))))))


;;;; -------------------------------------------------------------------------
;;;; Tiled map support — query helpers
;;;; -------------------------------------------------------------------------

(defun tilemap-get-layer (tilemap-component layer-name)
  "Return the layer plist whose :name equals LAYER-NAME, or NIL.
  TILEMAP-COMPONENT is the plist returned by GET-COMPONENT for the tilemap
  component, or the dot-notation variable inside a DEFSYSTEM body."
  (find layer-name
        (getf tilemap-component :layers)
        :key  (lambda (l) (getf l :name))
        :test #'equal))

(defun tilemap-get-objects (tilemap-component layer-name)
  "Return the list of object plists from the object layer named LAYER-NAME, or NIL.
  Each object plist has keys: :id :name :type :x :y :width :height :properties.

  Example — spawn enemies from an object layer:
    (dolist (obj (tilemap-get-objects tilemap \"Enemies\"))
      (spawn (transform :x (getf obj :x) :y (getf obj :y))
             (enemy :kind (getf obj :type))))"
  (let ((layer (tilemap-get-layer tilemap-component layer-name)))
    (when (and layer (eq (getf layer :type) :object))
      (getf layer :objects))))

(defun tilemap-tile-at (tilemap-component layer-name tx ty)
  "Return the GID of the tile at tile coordinates (TX, TY) in the tile layer
  named LAYER-NAME.  Returns 0 for empty tiles or out-of-bounds coordinates.

  Example — simple tile collision:
    (unless (zerop (tilemap-tile-at tilemap \"Collision\" tile-x tile-y))
      (resolve-collision ...))"
  (let ((layer (tilemap-get-layer tilemap-component layer-name)))
    (when (and layer (eq (getf layer :type) :tile))
      (let ((lw (getf layer :width))
            (lh (getf layer :height)))
        (if (and (>= tx 0) (< tx lw) (>= ty 0) (< ty lh))
            (aref (getf layer :data) (+ (* ty lw) tx))
            0)))))

(defun tilemap-world-to-tile (tilemap-component wx wy)
  "Convert world-space pixel coordinates (WX, WY) to tile coordinates (TX, TY).
  Assumes the map origin is at (0, 0); subtract the tilemap entity's transform
  before calling if the map is offset."
  (values (floor wx (getf tilemap-component :tile-width))
          (floor wy (getf tilemap-component :tile-height))))


;;;; -------------------------------------------------------------------------
;;;; Camera — component and system
;;;; -------------------------------------------------------------------------

(defcomponent camera (x y smooth target clamp-x0 clamp-y0 clamp-x1 clamp-y1))

(defsystem update-camera :with (camera)
  "Move the camera toward its TARGET using delta-time-independent lerp, then
  clamp the result within the declared world bounds.  Writes the final position
  to *CAMERA-X* and *CAMERA-Y* so DRAW-TEXTURE picks it up automatically.
  Always call this before any render system each frame."
  (let* ((sw  *screen-width*)
         (sh  *screen-height*)
         (cx  camera.x)
         (cy  camera.y)
         (tgt camera.target))

    (when tgt
      (let* ((tpos   (get-component tgt 'transform))
             (dest-x (- (getf tpos :x) (ash sw -1)))
             (dest-y (- (getf tpos :y) (ash sh -1)))
             (spd    camera.smooth))
        (if (or (null spd) (zerop spd))
            (setf cx dest-x
                  cy dest-y)
            (let ((alpha (float (* spd *dt*) 1.0d0)))
              (setf cx (round (+ cx (* alpha (- dest-x cx))))
                    cy (round (+ cy (* alpha (- dest-y cy)))))))))

    (let ((x0 camera.clamp-x0) (y0 camera.clamp-y0)
          (x1 camera.clamp-x1) (y1 camera.clamp-y1))
      (when (and x0 x1)
        (setf cx (max x0 (min cx (- x1 sw)))))
      (when (and y0 y1)
        (setf cy (max y0 (min cy (- y1 sh))))))

    (setf camera.x    cx
          camera.y    cy
          *camera-x*  cx
          *camera-y*  cy)))


;;;; -------------------------------------------------------------------------
;;;; Camera — helpers
;;;; -------------------------------------------------------------------------

(defun camera-snap (camera-entity)
  "Teleport the camera immediately to its target, bypassing the smooth lerp.
  Call this in :on-init after spawning the camera to avoid a slide-in on the
  first frame.  CAMERA-ENTITY is the entity returned by SPAWN."
  (let* ((cam  (get-component camera-entity 'camera))
         (tgt  (getf cam :target))
         (tpos (when tgt (get-component tgt 'transform))))
    (when tpos
      (let ((nx (- (getf tpos :x) (ash *screen-width*  -1)))
            (ny (- (getf tpos :y) (ash *screen-height* -1))))
        (setf (getf cam :x) nx
              (getf cam :y) ny
              *camera-x*    nx
              *camera-y*    ny)))))

(defun camera-set-clamp (camera-entity x0 y0 x1 y1)
  "Update the world bounds used for camera clamping at runtime.
  Pass NIL for both X0/X1 or Y0/Y1 to disable clamping on that axis.

  Example — after loading a new level:
    (camera-set-clamp *cam* 0 0 (* cols tile-w) (* rows tile-h))
    (camera-snap *cam*)"
  (let ((cam (get-component camera-entity 'camera)))
    (setf (getf cam :clamp-x0) x0
          (getf cam :clamp-y0) y0
          (getf cam :clamp-x1) x1
          (getf cam :clamp-y1) y1)))

(defun camera-set-target (camera-entity target-entity)
  "Change the camera's follow target to TARGET-ENTITY at runtime.
  TARGET-ENTITY must have a TRANSFORM component."
  (setf (getf (get-component camera-entity 'camera) :target)
        target-entity))

(defun camera-world-to-screen (wx wy)
  "Convert world-space coordinates (WX, WY) to screen-space coordinates.
  Returns two values: (screen-x screen-y).
  Useful for drawing UI elements anchored to world positions."
  (values (- wx *camera-x*)
          (- wy *camera-y*)))

(defun camera-screen-to-world (sx sy)
  "Convert screen-space coordinates (SX, SY) to world-space coordinates.
  Returns two values: (world-x world-y).
  Useful for mapping mouse/touch input to world positions."
  (values (+ sx *camera-x*)
          (+ sy *camera-y*)))


;;;; -------------------------------------------------------------------------
;;;; Entry point
;;;; -------------------------------------------------------------------------

(defun run (title width height fps initial-scene)
  "Initialise the engine and run the game loop until the window is closed.

  TITLE         — window title string.
  WIDTH HEIGHT  — window dimensions in pixels; also set *SCREEN-WIDTH/HEIGHT*.
  FPS           — target frame rate; pass 0 to run uncapped.
  INITIAL-SCENE — symbol naming the first scene to activate (via SWITCH-SCENE).

  The loop sequence each frame:
    1. Compute delta-time and bind *DT*.
    2. Call UPDATE, which dispatches to the current scene's :on-going hook.
    3. Call FLUSH-BATCH to submit all queued draw calls to OpenGL.
    4. Swap buffers and poll events.
    5. Busy-wait if necessary to honour the FPS cap.

  On exit, :on-exit is called on the current scene, all assets are freed, and
  the VAO/VBO and shader program are deleted before GLFW terminates."
  (unless (= (glfw-init) 1)
    (error "GLFW initialisation failed"))

  (let ((win (glfw-create-window width height title (null-ptr) (null-ptr))))
    (when (null-ptr-p win)
      (glfw-terminate)
      (error "Failed to create GLFW window"))

    (setf *window*        win
          *screen-width*  width
          *screen-height* height)
    (glfw-make-context-current win)
    (glfw-swap-interval 0)

    (gl-enable +blend+)
    (gl-blend-func +src-alpha+ +one-minus-src-alpha+)

    (let ((prog (make-shader-program *vert-src* *frag-src*)))
      (multiple-value-bind (vao vbo) (make-batch-renderer)
        (setf *batch-vao*    vao
              *batch-vbo*    vbo
              *sprite-shader* prog)

        (gl-use-program prog)
        (gl-uniform-1i (gl-get-uniform-location prog "uTexture") 0)
        (gl-uniform-4f (gl-get-uniform-location prog "uTint") 1.0f0 1.0f0 1.0f0 1.0f0)

        (switch-scene initial-scene)

        (let* ((target-dt (if (> fps 0) (/ 1.0d0 fps) 0.0d0))
               (last-time (glfw-get-time)))

          (loop while (= 0 (glfw-window-should-close win)) do
            (let* ((frame-start (glfw-get-time))
                   (dt          (- frame-start last-time)))
              (setf last-time frame-start)

              (gl-clear-color 0.2f0 0.2f0 0.2f0 1.0f0)
              (gl-clear +color-buffer-bit+)

              (let ((*dt* dt))
                (update))

              (flush-batch)

              (glfw-swap-buffers win)
              (glfw-poll-events)

              (when (> target-dt 0.0d0)
                (let ((remaining (- target-dt (- (glfw-get-time) frame-start))))
                  (when (> remaining 0.002d0)
                    (sleep (- remaining 0.002d0)))
                  (loop while (< (- (glfw-get-time) frame-start) target-dt)))))))

        (when *current-scene*
          (funcall (getf *current-scene* :on-exit)))

        (asset-free-all)

        (with-alien ((p unsigned-int vao) (q unsigned-int vbo))
          (gl-delete-vertex-arrays 1 (addr p))
          (gl-delete-buffers      1 (addr q)))
        (gl-delete-program prog))))

  (setf *window* nil)
  (glfw-terminate))

(defun run-with-ui (title width height fps initial-scene)
  "Like RUN, but with the Nuklear GUI layer fully integrated.

  TITLE         — window title string.
  WIDTH HEIGHT  — window dimensions in pixels.
  FPS           — target frame rate; 0 for uncapped.
  INITIAL-SCENE — symbol naming the first scene to activate.

  The frame sequence differs slightly from plain RUN:

    1. glfwPollEvents is called FIRST so Nuklear sees fresh input.
    2. nk_glfw3_new_frame — Nuklear processes that input.
    3. glClear.
    4. UPDATE — runs :on-going (declare panels and call SYSCALL render-ui here).
    5. gl-use-program + FLUSH-BATCH — draw all queued sprite quads.
    6. nk_glfw3_render — composite the Nuklear draw lists on top of sprites.
    7. glfwSwapBuffers.
    8. FPS cap if requested.

  On exit, NUI-SHUTDOWN is called automatically before GLFW terminates."
  (unless (= (glfw-init) 1)
    (error "GLFW initialisation failed"))

  (let ((win (glfw-create-window width height title (null-ptr) (null-ptr))))
    (when (null-ptr-p win)
      (glfw-terminate)
      (error "Failed to create GLFW window"))

    (setf *window*        win
          *screen-width*  width
          *screen-height* height)
    (glfw-make-context-current win)
    (glfw-swap-interval 0)

    (gl-enable +blend+)
    (gl-blend-func +src-alpha+ +one-minus-src-alpha+)

    (let ((nk-ctx (%nk-init win)))
      (when (null-ptr-p nk-ctx)
        (glfw-terminate)
        (error "Nuklear initialisation failed"))
      (setf *nk-ctx*    nk-ctx
            *nk-active* t))

    (let ((prog (make-shader-program *vert-src* *frag-src*)))
      (multiple-value-bind (vao vbo) (make-batch-renderer)
        (setf *batch-vao*     vao
              *batch-vbo*     vbo
              *sprite-shader* prog)

        (gl-use-program prog)
        (gl-uniform-1i (gl-get-uniform-location prog "uTexture") 0)
        (gl-uniform-4f (gl-get-uniform-location prog "uTint") 1.0f0 1.0f0 1.0f0 1.0f0)

        (switch-scene initial-scene)

        (let* ((target-dt (if (> fps 0) (/ 1.0d0 fps) 0.0d0))
               (last-time (glfw-get-time)))

          (loop while (= 0 (glfw-window-should-close win)) do
            (glfw-poll-events)

            (let* ((frame-start (glfw-get-time))
                   (dt          (- frame-start last-time)))
              (setf last-time frame-start)

              (%nk-new-frame)

              (gl-clear-color 0.2f0 0.2f0 0.2f0 1.0f0)
              (gl-clear +color-buffer-bit+)

              (let ((*dt* dt))
                (update))

              (gl-use-program *sprite-shader*)
              (gl-enable +blend+)
              (gl-blend-func +src-alpha+ +one-minus-src-alpha+)
              (flush-batch)

              (%nk-render)

              (glfw-swap-buffers win)

              (when (> target-dt 0.0d0)
                (let ((remaining (- target-dt (- (glfw-get-time) frame-start))))
                  (when (> remaining 0.002d0)
                    (sleep (- remaining 0.002d0)))
                  (loop while (< (- (glfw-get-time) frame-start) target-dt)))))))

        (when *current-scene*
          (funcall (getf *current-scene* :on-exit)))

        (nui-shutdown)
        (asset-free-all)

        (with-alien ((p unsigned-int vao) (q unsigned-int vbo))
          (gl-delete-vertex-arrays 1 (addr p))
          (gl-delete-buffers       1 (addr q)))
        (gl-delete-program prog))))

  (setf *window* nil)
  (glfw-terminate))
