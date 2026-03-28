;; tileset.lisp

(in-package :cl-aliengine)

(defstruct tilemap-tileset
  "Metadata for a Tiled tileset, paired with its GPU texture.
  TEXTURE  — GPU-TEXTURE of the sprite sheet image.
  FIRSTGID — the first global tile ID that belongs to this tileset.
  COLUMNS  — number of tile columns in the sprite sheet.
  TILE-W   — width of one tile in pixels.
  TILE-H   — height of one tile in pixels."
  texture firstgid columns tile-w tile-h)

(defun %tiled-dir (map-path)
  "Return the directory portion of MAP-PATH as a namestring with a trailing separator."
  (namestring
   (make-pathname :defaults (pathname map-path) :name nil :type nil)))

(defun %tiled-resolve (rel base-dir)
  "Resolve the relative path REL against BASE-DIR and return a namestring.
  Used to locate tileset images and external .tsj files relative to the map."
  (namestring (merge-pathnames rel (pathname base-dir))))

(defun %tiled-load-tileset-json (ts-json dir firstgid)
  "Construct a TILEMAP-TILESET from a parsed tileset JSON node TS-JSON.
  DIR is the base directory for resolving the image path.
  FIRSTGID is the global tile ID offset read from the map's tileset reference."
  (let* ((tw   (json-get ts-json "tilewidth"))
         (th   (json-get ts-json "tileheight"))
         (cols (json-get ts-json "columns"))
         (img  (json-get ts-json "image")))
    (unless img  (error "Tileset missing required field 'image'"))
    (unless cols (error "Tileset missing required field 'columns'"))
    (make-tilemap-tileset
     :texture  (asset-texture (%tiled-resolve img dir))
     :firstgid firstgid
     :columns  cols
     :tile-w   (or tw (error "Tileset missing required field 'tilewidth'"))
     :tile-h   (or th (error "Tileset missing required field 'tileheight'")))))
