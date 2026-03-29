;; src/core/libpng-bindings.lisp

(in-package :cl-aliengine)

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
