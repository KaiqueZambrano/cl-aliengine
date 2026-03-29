;; src/asset/globals.lisp

(in-package :cl-aliengine)

(defparameter *asset-cache* (make-hash-table :test #'equal)
  "Hash table mapping asset path strings to loaded resources (GPU-TEXTURE etc.).")