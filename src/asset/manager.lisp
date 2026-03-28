;; manager.lisp

(in-package :cl-aliengine)

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
