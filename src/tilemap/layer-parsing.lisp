;; layer-parsing.lisp

(in-package :cl-aliengine)

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

