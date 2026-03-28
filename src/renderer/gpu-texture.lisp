;; gpu-texture.lisp

(in-package :cl-aliengine)

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
