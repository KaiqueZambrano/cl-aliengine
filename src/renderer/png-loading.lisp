;; png-loading.lisp

(in-package :cl-aliengine)

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
