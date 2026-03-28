;; ffi-load.lisp

(in-package :cl-aliengine)

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

