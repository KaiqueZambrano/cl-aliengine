(defsystem "aliengine"
  :description "Simple 2D Game Engine"
  :author "Kaique T. Zambrano"
  :license "MIT"
  :serial nil

  :components
  ((:module "src"
    :pathname "src"
    :components
    ((:file "package")
     
     (:module "core"
      :depends-on ()
      :serial t
      :pathname "core"
      :components
      ((:file "ffi-load")
       (:file "utilities")
       (:file "globals")
       (:file "opengl-constants")
       (:file "opengl-bindings")
       (:file "libpng-constants")
       (:file "libpng-bindings")
       (:file "glfw-bindings")
       (:file "nuklear-constants")
       (:file "nuklear-bindings")
       (:file "miniaudio-bindings")))

     (:module "ecs"
      :depends-on ()
      :serial t
      :pathname "ecs"
      :components
      ((:file "globals")
       (:file "resources")
       (:file "dot-notation")
       (:file "entities")
       (:file "components")
       (:file "systems")
       (:file "scenes")))

     (:module "renderer"
      :depends-on ("core" "ecs")
      :serial t
      :pathname "renderer"
      :components
      ((:file "globals")
       (:file "png-loading")
       (:file "gpu-texture")
       (:file "shaders")
       (:file "texture-batch")
       (:file "components")
       (:file "systems")))

     (:module "asset"
      :depends-on ("core" "ecs" "renderer")
      :serial t
      :pathname "asset"
      :components
      ((:file "globals")
       (:file "manager")))

     (:module "input"
      :depends-on ("core" "ecs")
      :serial t
      :pathname "input"
      :components ((:file "input")))

     (:module "physics"
      :depends-on ("core" "ecs")
      :serial t
      :pathname "physics"
      :components
      ((:file "components")
       (:file "helpers")
       (:file "systems")))

     (:module "animation"
      :depends-on ("core" "ecs" "renderer")
      :serial t
      :pathname "animation"
      :components
      ((:file "components")
       (:file "macros")
       (:file "systems")))

     (:module "particles"
      :depends-on ("core" "ecs" "renderer")
      :serial t
      :pathname "particles"
      :components
      ((:file "components")
       (:file "systems")))

     (:module "camera"
      :depends-on ("core" "ecs")
      :serial t
      :pathname "camera"
      :components
      ((:file "components")
       (:file "helpers")
       (:file "systems")))

     (:module "tilemap"
      :depends-on ("core" "ecs" "renderer")
      :serial t
      :pathname "tilemap"
      :components
      ((:file "json-parser")
       (:file "tileset")
       (:file "layer-parsing")
       (:file "map-loader")
       (:file "components")
       (:file "helpers")
       (:file "systems")))

     (:module "ui"
      :depends-on ("core" "ecs" "renderer")
      :serial t
      :pathname "ui"
      :components
      ((:file "lifecycle")
       (:file "components")
       (:file "widget-macros")
       (:file "systems")))

     (:module "audio"
      :depends-on ("core" "ecs")
      :serial t
      :pathname "audio"
      :components
      ((:file "components")
       (:file "helpers")
       (:file "globals")
       (:file "lifecycle")
       (:file "systems")))

     (:module "runtime"
      :depends-on ("core" "ecs" "renderer" "asset" "input" "physics" "animation"
                   "particles" "camera" "tilemap" "ui" "audio")
      :pathname "runtime"
      :components
      ((:file "run")
       (:file "run-with-ui")))))))

(defsystem "aliengine/examples"
  :depends-on ("aliengine")
  :components
  ((:module "examples"
    :components
    ((:module "platformer"
      :components
      ((:file "game")))))))
