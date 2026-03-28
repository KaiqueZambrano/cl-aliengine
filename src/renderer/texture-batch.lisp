;; texture-batch.lisp

(in-package :cl-aliengine)

(defstruct batch-group
  "Holds the CPU-side vertex data for all quads sharing a single texture.
  FLOATS is the interleaved (x y u v) float array; COUNT is the next free float index."
  (floats (make-array *batch-group-floats* :element-type 'single-float :initial-element 0.0f0)
          :type (simple-array single-float (*)))
  (count  0 :type fixnum))

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

