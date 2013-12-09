(in-package :cl-nneat-demo)

(defclass food (game-object)
  ((amount :accessor food-amount :initform (1+ (random 2)))))

(defmethod run ((food food) (objects vector))
  nil)

(defmethod reset-object ((obj food) &key (x (random *window-x*))
                                                (y (random *window-y*))
                                                (speed 0)
                                                (angle 0))
  (setf (food-amount obj) (1+ (random 2)))
  (call-next-method obj :x x :y y :speed speed :angle angle))

(defmethod draw ((food food))
  (gl:color 0 0 1)
  (gl:push-matrix)
  (gl:translate (+ *window-padding* (x food))
                (+ *window-padding* (y food))
                0)
  (gl:begin :polygon)
  (let* ((fs (+ (/ (food-amount food) 3) *food-size*))
         (fsn (- fs)))
    (gl:vertex fsn fsn)
    (gl:vertex fs fsn)
    (gl:vertex fs fs)
    (gl:vertex fsn fs))
  (gl:end)
  (gl:pop-matrix))
