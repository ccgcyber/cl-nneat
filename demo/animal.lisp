(in-package :cl-nneat-demo)

(defclass animal (game-object)
  ((net :accessor animal-net :initarg :net :initform nil)
   (fitness :accessor animal-fitness :initform 0)
   (initial-genome-length :accessor animal-initial-genome-length :initarg :initial-genome-length :initform 0)
   (dead :accessor animal-dead :initform nil)
   (chewing :accessor animal-chewing :initform 0)))

(defmethod run ((animal animal) objects)
  (unless (animal-dead animal)
    (let ((vision (raytrace-nearby-objects animal objects)))
      (let ((inputs (loop for v across vision collect (get-classifier animal v))))
        (push (animal-chewing animal) inputs)
        (let ((outputs (run-net (animal-net animal) inputs)))
          ;(format t "inputs: ~a~%outputs: ~a~%" inputs outputs)
          (process-outputs animal objects outputs)
          (call-next-method animal objects))))))

(defun get-classifier (animal target)
  (let* ((classifier-config (hash-get *animal-config* (list (type-of animal) :classifiers)))
         (classifier (hash-get classifier-config (list (type-of target))))
         (empty (hash-get classifier-config '(empty))))
    (if classifier classifier empty)))

;(defmethod process-outputs ((animal animal) objects outputs))

(defun create-animal-of-type (obj-type)
  (let ((obj (make-instance obj-type
                            :net (create-basic-net :inputs (get-num-inputs obj-type)
                                                   :hidden (hash-get *animal-config*
                                                                     (list obj-type :hidden))
                                                   :outputs (hash-get *animal-config*
                                                                      (list obj-type :outputs))))))
    (setf (animal-initial-genome-length obj)
          (length (genome-genes (net-genome (animal-net obj)))))
    obj))

(defun raytrace-nearby-objects (animal objects &key reverse)
  (declare (optimize (speed 3) (safety 1))
           (type animal animal)
           (type vector objects)
           (type boolean reverse))
  (let* ((angle (if reverse (+ 180 (angle animal)) (angle animal)))
         (x (x animal))
         (y (y animal))
         (vision-config (hash-get *animal-config* (list (type-of animal) :vision)))
         (distance (hash-get vision-config '(:distance)))
         (search-domain (get-objects-of-interest animal
                                                 (x animal)
                                                 (y animal)
                                                 objects
                                                 :search-dist distance))
         (fov (hash-get vision-config '(:fov)))
         (num-rays (hash-get vision-config '(:angle-resolution)))
         (distance-res (hash-get vision-config '(:distance-resolution)))
         (num-spots (round distance-res))
         (search-speed (/ distance distance-res))
         (angle-diff (/ fov (if (= num-rays 1) 1 (1- num-rays))))
         (start (if (= num-rays 1) angle (- angle (/ fov 2))))
         (results (make-array (* num-rays distance-res) :initial-element nil))
         (index 0))
    (dotimes (ray num-rays)
      (let* ((direction (* (+ start (* ray angle-diff)) (/ pi 180)))
             (x-search (round (* (cos direction) search-speed)))
             (y-search (round (* (sin (- direction)) search-speed))))
        (dotimes (spot num-spots)
          (let ((search-x (+ x (* spot x-search)))
                (search-y (+ y (* spot y-search))))
            (let* ((nearby (get-objects-of-interest animal search-x search-y search-domain :search-dist (1+ (* spot (/ *search-distance* num-spots))) :except results :limit 1)))
              (unless (zerop (length nearby))
                (setf (aref results index) (aref nearby 0)))))
          (incf index))))
    results))

(defun get-objects-of-interest (animal x y objects &key except limit (search-dist *animal-awareness*))
  (declare (optimize (speed 3) (safety 1))
           (type animal animal)
           (type number x y)
           (type (vector game-object) objects)
           (type (or (vector game-object) null) except)
           (type (or integer null) limit)
           (type number search-dist))
  (let ((sxp (+ x search-dist))
        (sxn (- x search-dist))
        (syp (+ y search-dist))
        (syn (- y search-dist))
        (new-objects (make-array 0 :fill-pointer t :adjustable t)))
    (loop for o across objects do
          (unless (or (eql o animal)
                      (and except (contains except o))
                      (< (x o) sxn)
                      (< sxp (x o))
                      (< (y o) syn)
                      (< syp (y o)))
            (vector-push-extend o new-objects))
          (when (and limit (<= limit (length new-objects)))
            (return-from get-objects-of-interest new-objects)))
    new-objects))

(defun get-num-inputs (animal-type)
  (let* ((vision-config (hash-get *animal-config* (list animal-type :vision))))
    (1+ (* (hash-get vision-config '(:angle-resolution))
           (hash-get vision-config '(:distance-resolution))))))
  
