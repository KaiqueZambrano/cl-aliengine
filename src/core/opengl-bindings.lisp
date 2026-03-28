;; opengl-bindings.lisp

(in-package :cl-aliengine)

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
