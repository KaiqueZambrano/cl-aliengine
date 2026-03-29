;; src/renderer/shaders.lisp

(in-package :cl-aliengine)

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
