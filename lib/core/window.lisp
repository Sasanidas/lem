(in-package :lem)

(export '(line-wrap
          *default-popup-message-timeout*
          *window-sufficient-width*
          *scroll-recenter-p*
          *window-scroll-functions*
          *window-size-change-functions*
          *window-show-buffer-functions*
          find-window
          window-view-point
          windowp
          window-id
          window-x
          window-y
          window-width
          window-height
          window-buffer
          window-view
          last-print-cursor-x
          last-print-cursor-y
          window-parameter
          window-delete-hook
          window-redraw
          current-window
          window-list
          one-window-p
          deleted-window-p
          window-recenter
          window-scroll
          window-cursor-x
          window-cursor-y
          move-to-next-virtual-line
          move-to-previous-virtual-line
          point-virtual-line-column
          move-to-virtual-line-column
          window-see
          split-window-vertically
          split-window-horizontally
          split-window-sensibly
          get-next-window
          delete-window
          get-buffer-windows
          other-buffer
          switch-to-buffer
          pop-to-buffer
          left-window
          right-window
          up-window
          down-window
          make-floating-window
          floating-window
          floating-window-border
          floating-window-p
          header-window
          redraw-display
          display-popup-message
          delete-popup-message))

(define-editor-variable line-wrap t)

(defparameter *window-left-margin* 1)
(defparameter *default-popup-message-timeout* 5)
(defparameter *window-sufficient-width* 150)
(defparameter *scroll-recenter-p* t)

(defparameter *window-scroll-functions* '())
(defparameter *window-size-change-functions* '())
(defparameter *window-show-buffer-functions* '())

(defparameter *use-new-vertical-move-function* t)
(defparameter *use-cursor-movement-workaround* t)

(defvar *window-id-counter* 0)

(defclass window ()
  ((id
    :initform (mod (incf *window-id-counter*) most-positive-fixnum)
    :reader window-id
    :type fixnum)
   (x
    :initarg :x
    :reader window-x
    :writer set-window-x
    :type fixnum)
   (y
    :initarg :y
    :reader window-y
    :writer set-window-y
    :type fixnum)
   (width
    :initarg :width
    :reader window-width
    :writer set-window-width
    :type fixnum)
   (height
    :initarg :height
    :reader window-height
    :writer set-window-height
    :type fixnum)
   (buffer
    :initarg :buffer
    :reader window-buffer
    :writer set-window-buffer
    :type buffer)
   (screen
    :reader window-screen
    :writer set-window-screen)
   (view-point
    :reader window-view-point
    :writer set-window-view-point
    :type point)
   (point
    :reader %window-point
    :writer set-window-point
    :type point)
   (delete-hook
    :initform nil
    :accessor window-delete-hook)
   (switch-to-buffer-hook
    :initform nil
    :accessor window-switch-to-buffer-hook)
   (use-modeline-p
    :initarg :use-modeline-p
    :initform nil
    :reader window-use-modeline-p
    :type boolean)
   (modeline-format
    :initform nil
    :accessor window-modeline-format)
   (parameters
    :initform nil
    :accessor window-parameters)))

(defmethod set-window-buffer :before (buffer (window window))
  (screen-modify (window-screen window)))

(defun window-height-without-modeline (window)
  (- (window-height window)
     (if (window-use-modeline-p window) 1 0)))

(defun make-view-from-window (window)
  (lem-if:make-view (implementation)
                    window
                    (window-x window)
                    (window-y window)
                    (window-width window)
                    (window-height-without-modeline window)
                    (window-use-modeline-p window)))

(defmethod initialize-instance :after ((window window) &rest initargs)
  (declare (ignore initargs))
  (set-window-screen (make-screen (make-view-from-window window)
                                  (window-width window)
                                  (window-height-without-modeline window))
                     window)
  (set-window-view-point (buffer-start
                          (copy-point (buffer-point (window-buffer window))
                                      :right-inserting))
                         window)
  (set-window-point (copy-point (buffer-start-point (window-buffer window))
                                :right-inserting)
                    window))

(defun windowp (x) (typep x 'window))

(defun make-window (buffer x y width height use-modeline-p)
  (make-instance 'window
                 :buffer buffer
                 :x x
                 :y y
                 :width width
                 :height height
                 :use-modeline-p use-modeline-p))

(defun clear-screens-of-window-list ()
  (dolist (window (all-window-list))
    (screen-clear (window-screen window))))

(defgeneric %delete-window (window))
(defgeneric window-redraw (window force)
  (:method (window force)
    (redraw-display-window window force)))

(defun window-view (window)
  (screen-view (window-screen window)))

(defmethod last-print-cursor-x ((window window))
  "最後にカーソルを描画した時のX座標を返します。
各フロントエンドでカーソルを画面に表示するために使うためのものであり、
それ以外での使用は推奨しません。(SHOULD NOT)"
  (screen-last-print-cursor-x (window-screen window)))

(defmethod last-print-cursor-y ((window window))
  "最後にカーソルを描画した時のY座標を返します。
各フロントエンドでカーソルを画面に表示するために使うためのものであり、
それ以外での使用は推奨しません。(SHOULD NOT)"
  (screen-last-print-cursor-y (window-screen window)))

(defun find-window (id)
  (window-tree-find-if (window-tree)
                       (lambda (window)
                         (= id (window-id window)))))

(defun window-buffer-point (window)
  (buffer-point (window-buffer window)))

(defun window-point (window)
  (if (eq window (current-window))
      (window-buffer-point window)
      (%window-point window)))

(defun window-parameter (window parameter)
  (getf (window-parameters window) parameter))

(defun (setf window-parameter) (value window parameter)
  (setf (getf (window-parameters window) parameter) value))

(defun current-window ()
  (frame-current-window (current-frame)))

(defun (setf current-window) (new-window)
  (let ((frame (current-frame)))
    (check-type new-window window)
    (when (frame-current-window frame)
      (let ((old-window (current-window)))
        (move-point (%window-point old-window)
                    (window-buffer-point old-window))))
    (let ((buffer (window-buffer new-window)))
      (setf (current-buffer) buffer)
      (move-point (buffer-point buffer)
                  (%window-point new-window)))
    (setf (frame-current-window frame) new-window)))

(defun window-tree ()
  (frame-window-tree (current-frame)))

(defun (setf window-tree) (new-window-tree)
  (let ((frame (current-frame)))
    (setf (frame-window-tree frame) new-window-tree)))

(defstruct (window-node (:constructor %make-window-node))
  split-type
  car
  cdr)

(defun make-window-node (split-type car cdr)
  (assert (member split-type '(:hsplit :vsplit)))
  (%make-window-node :split-type split-type
                     :car car
                     :cdr cdr))

(defun window-tree-leaf-p (window)
  (windowp window))

(defun window-tree-map (tree fn)
  (labels ((f (tree)
             (cond ((window-tree-leaf-p tree)
                    (funcall fn tree))
                   (t
                    (f (window-node-car tree))
                    (f (window-node-cdr tree))))))
    (f tree)
    nil))

(defun window-tree-flatten (tree)
  (let ((windows))
    (window-tree-map tree
                     (lambda (win)
                       (push win windows)))
    (nreverse windows)))

(defun window-tree-find (tree window)
  (window-tree-map tree
                   (lambda (win)
                     (when (eq win window)
                       (return-from window-tree-find win)))))

(defun window-tree-find-if (tree test)
  (window-tree-map tree
                   (lambda (win)
                     (when (funcall test win)
                       (return-from window-tree-find-if win)))))

(defun window-tree-parent (tree node)
  (cond ((window-tree-leaf-p tree) nil)
        ((eq node (window-node-car tree))
         (values tree
                 (lambda ()
                   (window-node-car tree))
                 (lambda (new-value)
                   (setf (window-node-car tree) new-value))
                 (lambda ()
                   (window-node-cdr tree))
                 (lambda (new-value)
                   (setf (window-node-cdr tree) new-value))))
        ((eq node (window-node-cdr tree))
         (values tree
                 (lambda ()
                   (window-node-cdr tree))
                 (lambda (new-value)
                   (setf (window-node-cdr tree) new-value))
                 (lambda ()
                   (window-node-car tree))
                 (lambda (new-value)
                   (setf (window-node-car tree) new-value))))
        (t
         (multiple-value-bind (parent
                               getter
                               setter
                               another-getter
                               another-setter)
             (window-tree-parent (window-node-car tree) node)
           (if parent
               (values parent getter setter another-getter another-setter)
               (window-tree-parent (window-node-cdr tree) node))))))

(defun window-list (&optional (frame (current-frame)))
  (window-tree-flatten (frame-window-tree frame)))

(defun all-window-list (&optional (frame (current-frame)))
  (append (window-tree-flatten (frame-window-tree frame))
          (frame-header-windows frame)
          (frame-floating-windows frame)
          (uiop:ensure-list (frame-sidebar-window frame))))

(defun one-window-p ()
  (window-tree-leaf-p (window-tree)))

(defun deleted-window-p (window)
  (cond ((window-tree-find (window-tree) window)
         nil)
        ((find window (frame-floating-windows (current-frame)))
         nil)
        (t t)))

(defun %free-window (window)
  (delete-point (window-view-point window))
  (delete-point (%window-point window))
  (screen-delete (window-screen window)))

(defun setup-frame-windows (frame buffer)
  (assert (= (length (frame-header-windows frame))
             (length (frame-header-windows (current-frame)))))
  (let ((window (make-window buffer
                             (topleft-window-x (current-frame))
                             (topleft-window-y (current-frame))
                             (max-window-width (current-frame))
                             (max-window-height (current-frame))
                             t)))
    (setf (frame-current-window frame) window)
    (setf (frame-window-tree frame) window)))

(defun teardown-windows (frame)
  (mapc #'%free-window (all-window-list frame)))

(defun window-recenter (window)
  (line-start
   (move-point (window-view-point window)
               (window-buffer-point window)))
  (let* ((height (window-height-without-modeline window))
         (n      (- (window-cursor-y window)
                    (floor height 2))))
    (window-scroll window n)
    n))

(defun %calc-window-cursor-x (point window)
  "Return (values cur-x next). the 'next' is a flag if the cursor goes to
next line because it is at the end of width."
  (unless (variable-value 'line-wrap :default (window-buffer window))
    (return-from %calc-window-cursor-x (values (point-column point) nil)))
  (let* ((tab-size (variable-value 'tab-width :default (window-buffer window)))
         (charpos (point-charpos point))
         (line    (line-string point))
         (width   (1- (window-width window)))
         (cur-x   0)
         (add-x   (if (< charpos (length line))
                      (char-width (schar line charpos) 0 :tab-size tab-size)
                      1)))
    (loop :for i :from 0 :below charpos
          :for c := (schar line i)
          :do (setf cur-x (char-width c cur-x :tab-size tab-size))
              (when (< width cur-x)
                (setf cur-x (char-width c 0 :tab-size tab-size))))
    (if (< width (+ cur-x add-x))
        (values 0     t)
        (values cur-x nil))))

(defun window-cursor-x (window)
  (multiple-value-bind (x next)
      (%calc-window-cursor-x (window-buffer-point window) window)
    (declare (ignore next))
    x))

(defun cursor-goto-next-line-p (point window)
  "Check if the cursor goes to next line because it is at the end of width."
  (multiple-value-bind (x next)
      (%calc-window-cursor-x point window)
    (declare (ignore x))
    next))

(defun map-wrapping-line (window string fn)
  (let ((tab-size (variable-value 'tab-width :default (window-buffer window))))
    (loop :with start := 0
          :and width := (1- (window-width window))
          :for i := (wide-index string width :start start :tab-size tab-size)
          :while i
          :do (funcall fn i)
              (setq start i))))

(defun window-wrapping-offset (window start-point end-point)
  (unless (variable-value 'line-wrap :default (window-buffer window))
    (return-from window-wrapping-offset 0))
  (let ((offset 0))
    (labels ((inc (arg)
               (declare (ignore arg))
               (incf offset)))
      (map-region start-point
                  end-point
                  (lambda (string lastp)
                    (declare (ignore lastp))
                    (map-wrapping-line window
                                       string
                                       #'inc)))
      offset)))

(defun window-cursor-y-not-wrapping (window)
  (count-lines (window-buffer-point window)
               (window-view-point window)))

(defun window-cursor-y (window)
  (if (point< (window-buffer-point window)
              (window-view-point window))
      ;; return minus number
      (- (+ (window-cursor-y-not-wrapping window)
            (window-wrapping-offset window
                                    (backward-line-wrap
                                     (copy-point (window-buffer-point window)
                                                 :temporary)
                                     window t)
                                    (window-view-point window))
            (if (cursor-goto-next-line-p (window-view-point window) window)
                1 0)))
      ;; return zero or plus number
      (+ (window-cursor-y-not-wrapping window)
         (window-wrapping-offset window
                                 (window-view-point window)
                                 (window-buffer-point window))
         (if (and (point< (window-view-point window)
                          (window-buffer-point window))
                  (cursor-goto-next-line-p (window-buffer-point window) window))
             1 0))))

(defun forward-line-wrap (point window)
  (assert (eq (point-buffer point) (window-buffer window)))
  (when (variable-value 'line-wrap :default (point-buffer point))
    (map-wrapping-line window
                       (line-string point)
                       (lambda (i)
                         (when (< (point-charpos point) i)
                           (line-offset point 0 i)
                           (return-from forward-line-wrap point))))))

(defun backward-line-wrap-1 (point window contain-same-line-p)
  (if (and contain-same-line-p (start-line-p point))
      point
      (let (previous-charpos)
        (map-wrapping-line window
                           (line-string point)
                           (lambda (i)
                             (cond ((and contain-same-line-p (= i (point-charpos point)))
                                    (line-offset point 0 i)
                                    (return-from backward-line-wrap-1 point))
                                   ((< i (point-charpos point))
                                    (setf previous-charpos i))
                                   (previous-charpos
                                    (line-offset point 0 previous-charpos)
                                    (return-from backward-line-wrap-1 point))
                                   ((or contain-same-line-p (= i (point-charpos point)))
                                    (line-start point)
                                    (return-from backward-line-wrap-1 point)))))
        (cond (previous-charpos
               (line-offset point 0 previous-charpos))
              (contain-same-line-p
               (line-start point))))))

(defun backward-line-wrap (point window contain-same-line-p)
  (assert (eq (point-buffer point) (window-buffer window)))
  (cond ((variable-value 'line-wrap :default (point-buffer point))
         (backward-line-wrap-1 point window contain-same-line-p))
        (contain-same-line-p
         (line-start point))))

(defun move-to-next-virtual-line-1 (point window)
  (assert (eq (point-buffer point) (window-buffer window)))
  (or (forward-line-wrap point window)
      (line-offset point 1)))

(defun move-to-previous-virtual-line-1 (point window)
  (assert (eq (point-buffer point) (window-buffer window)))
  (backward-line-wrap point window t)
  (or (backward-line-wrap point window nil)
      (progn
        (and (line-offset point -1)
             (line-end point)
             (backward-line-wrap point window t)))))

(defun move-to-next-virtual-line-n (point window n)
  (assert (eq (point-buffer point) (window-buffer window)))
  (when (<= n 0)
    (return-from move-to-next-virtual-line-n point))
  (unless (variable-value 'line-wrap :default (point-buffer point))
    (return-from move-to-next-virtual-line-n (line-offset point n)))
  (loop :with n1 := n
        :do (map-wrapping-line
             window
             (line-string point)
             (lambda (i)
               (when (< (point-charpos point) i)
                 (decf n1)
                 (when (<= n1 0)
                   ;; cursor-x offset is recovered by (get-next-line-context-column)
                   (line-offset point 0 i)
                   (return-from move-to-next-virtual-line-n point)))))
            ;; go to next line
            (unless (line-offset point 1)
              (return-from move-to-next-virtual-line-n nil))
            (decf n1)
            (when (<= n1 0)
              (return-from move-to-next-virtual-line-n point))))

(defun move-to-previous-virtual-line-n (point window n)
  (assert (eq (point-buffer point) (window-buffer window)))
  (when (<= n 0)
    (return-from move-to-previous-virtual-line-n point))
  (unless (variable-value 'line-wrap :default (point-buffer point))
    (return-from move-to-previous-virtual-line-n (line-offset point (- n))))
  (let ((pos-ring  (make-array (1+ n))) ; ring buffer of wrapping position
        (pos-size  (1+ n))
        (pos-count 0)
        (pos-next  0)
        (pos-last  0))
    (flet ((pos-ring-push (pos)
             (setf (aref pos-ring pos-next) pos)
             (incf pos-next)
             (when (>= pos-next pos-size) (setf pos-next 0))
             (incf pos-count)
             (when (> pos-count pos-size)
               (setf pos-count pos-size)
               (incf pos-last)
               (when (>= pos-last pos-size) (setf pos-last 0)))))
      (loop :with n1 := n
            :with first-line := t
            :do (block outer
                  (pos-ring-push 0)
                  (map-wrapping-line
                   window
                   (line-string point)
                   (lambda (i)
                     (when (and first-line
                                (< (point-charpos point) i))
                       (return-from outer))
                     (pos-ring-push i))))
                (when (>= pos-count (1+ n1))
                  ;; cursor-x offset is recovered by (get-next-line-context-column)
                  (line-offset point 0 (aref pos-ring pos-last))
                  (return-from move-to-previous-virtual-line-n point))
                ;; go to previous line
                (unless (line-offset point -1)
                  (return-from move-to-previous-virtual-line-n nil))
                (setf first-line nil)
                (decf n1 pos-count)
                (setf pos-size  (1+ n1)) ; shrink ring-buffer
                (setf pos-count 0)
                (setf pos-next  0)
                (setf pos-last  0)))))

(defun move-to-next-virtual-line (point &optional n (window (current-window)))
  (unless n (setf n 1))
  (unless (zerop n)

    ;; workaround for cursor movement problem
    (when (and *use-cursor-movement-workaround*
               (eq point (window-buffer-point window))
               (variable-value 'line-wrap :default (point-buffer point))
               (numberp (get-next-line-context-column))
               (>= (get-next-line-context-column) (- (window-width window) 3)))
      (save-next-line-context-column 0))

    (if *use-new-vertical-move-function*
        (if (plusp n)
            (move-to-next-virtual-line-n point window n)
            (move-to-previous-virtual-line-n point window (- n)))
        (multiple-value-bind (n f)
            (if (plusp n)
                (values n #'move-to-next-virtual-line-1)
                (values (- n) #'move-to-previous-virtual-line-1))
          (loop :repeat n
                :do (unless (funcall f point window)
                      (return-from move-to-next-virtual-line nil)))
          point))))

(defun move-to-previous-virtual-line (point &optional n (window (current-window)))
  (move-to-next-virtual-line point (if n (- n) -1) window))

(defun point-virtual-line-column (point &optional (window (current-window)))
  (if (variable-value 'line-wrap :default (point-buffer point))
      (let ((column (point-column point)))
        (with-point ((start point))
          (backward-line-wrap start window t)
          (- column (point-column start))))
      (point-column point)))

(defun move-to-virtual-line-column (point column &optional (window (current-window)))
  (backward-line-wrap point window t)
  (let ((w 0))
    (loop
      :while (< w column)
      :do (setf w (char-width (character-at point) w))
          (when (end-line-p point) (return))
          (character-offset point 1))))

(defun window-scroll-down (window)
  (move-to-next-virtual-line (window-view-point window) 1 window))

(defun window-scroll-up (window)
  (move-to-previous-virtual-line (window-view-point window) 1 window))

(defun window-scroll-down-n (window n)
  (move-to-next-virtual-line (window-view-point window) n window))

(defun window-scroll-up-n (window n)
  (move-to-previous-virtual-line (window-view-point window) n window))

(defun window-scroll (window n)
  (screen-modify (window-screen window))
  (prog1 (if *use-new-vertical-move-function*
             (if (plusp n)
                 (window-scroll-down-n window n)
                 (window-scroll-up-n window (- n)))
             (dotimes (_ (abs n))
               (if (plusp n)
                   (window-scroll-down window)
                   (window-scroll-up window))))
    (run-hooks *window-scroll-functions* window)))

(defun adjust-view-point (window)
  "When the window view point is at the middle of wrapped line and
window width is changed, we must recalc the window view point."
  (unless (variable-value 'line-wrap :default (window-buffer window))
    (return-from adjust-view-point nil))
  (when (start-line-p (window-view-point window))
    (return-from adjust-view-point nil))
  (let ((point (window-view-point window))
        (i1    0))
    (map-wrapping-line
     window
     (line-string point)
     (lambda (i)
       (when (= (point-charpos point) i)
         (return-from adjust-view-point nil))
       (when (< (point-charpos point) i)
         (line-offset point 0 i1)
         (return-from adjust-view-point point))
       (setf i1 i)))
    (line-offset point 0 i1)
    point))

(defun window-offset-view (window)
  (if (point< (window-buffer-point window)
              (window-view-point window))
      ;; return minus number
      (window-cursor-y window)
      ;; return zero or plus number
      (let ((height (window-height-without-modeline window)))
        (max 0 (- (window-cursor-y window)
                  (1- height))))))

(defun window-see (window &optional (recenter *scroll-recenter-p*))
  (adjust-view-point window)
  (let ((offset (window-offset-view window)))
    (unless (zerop offset)
      (cond (recenter
             (window-recenter window)
             nil)
            (t
             (window-scroll window offset)
             offset)))))

(defun split-window-after (current-window new-window split-type)
  (assert (not (eq current-window new-window)))
  (window-set-size current-window
                   (window-width current-window)
                   (window-height current-window))
  (move-point (window-view-point new-window)
              (window-view-point current-window))
  (move-point (%window-point new-window)
              (window-buffer-point current-window))
  (move-point (window-buffer-point new-window)
              (window-buffer-point current-window))
  (window-see new-window)
  (multiple-value-bind (node getter setter)
      (window-tree-parent (window-tree) current-window)
    (if (null node)
        (setf (window-tree)
              (make-window-node split-type
                                current-window
                                new-window))
        (funcall setter
                 (make-window-node split-type
                                   (funcall getter)
                                   new-window))))
  t)

(defun check-before-splitting-window (window)
  (when (floating-window-p window)
    (editor-error "Can not split this window")))

(defun split-window-vertically (window &optional height)
  (check-before-splitting-window window)
  (let* ((use-modeline-p t)
         (min (+ 1 (if use-modeline-p 1 0)))
         (max (- (window-height window) min)))
    (cond ((null height)
           (setf height (floor (window-height window) 2)))
          ((> min height)
           (setf height min))
          ((< max height)
           (setf height max))))
  (unless (< 1 height)
    (editor-error "Can not split this window"))
  (let ((new-window
          (make-window (window-buffer window)
                       (window-x window)
                       (+ (window-y window) height)
                       (window-width window)
                       (- (window-height window) height)
                       t)))
    (set-window-height height window)
    (split-window-after window new-window :vsplit)
    (lem-if:split-window-vertically (implementation)
                                    (window-view window)
                                    (window-view new-window))))

(defun split-window-horizontally (window &optional width)
  (check-before-splitting-window window)
  (let* ((fringe-size 0)
         (min (+ 2 fringe-size))
         (max (- (window-width window) min)))
    (cond ((null width)
           (setf width (floor (window-width window) 2)))
          ((> min width)
           (setf width min))
          ((< max width)
           (setf width max))))
  (unless (< 1 width)
    (editor-error "Can not split this window"))
  (let ((new-window
          (make-window (window-buffer window)
                       (+ *window-left-margin* (window-x window) width)
                       (window-y window)
                       (- (window-width window) width *window-left-margin*)
                       (window-height window)
                       t)))
    (set-window-width width window)
    (split-window-after window new-window :hsplit)
    (lem-if:split-window-horizontally (implementation)
                                      (window-view window)
                                      (window-view new-window))))

(defun split-window-sensibly (window)
  (if (< *window-sufficient-width* (window-width window))
      (split-window-horizontally window)
      (split-window-vertically window)))

(defun get-next-window (window &optional (window-list (window-list)))
  (let ((result (member window window-list)))
    (if (cdr result)
        (cadr result)
        (car window-list))))

(defun window-set-pos (window x y)
  (when (floating-window-p window)
    (notify-floating-window-modified (current-frame)))
  (screen-set-pos (window-screen window) x y)
  (set-window-x x window)
  (set-window-y y window))

(defun window-set-size (window width height)
  (when (floating-window-p window)
    (notify-floating-window-modified (current-frame)))
  (set-window-width width window)
  (set-window-height height window)
  (screen-set-size (window-screen window)
                   width
                   (- height
                      (if (window-use-modeline-p window) 1 0))))

(defun window-move (window dx dy)
  (window-set-pos window
                  (+ (window-x window) dx)
                  (+ (window-y window) dy)))

(defun window-resize (window dw dh)
  (window-set-size window
                   (+ (window-width window) dw)
                   (+ (window-height window) dh))
  (run-hooks *window-size-change-functions* window))

(defun adjust-size-windows-after-delete-window (deleted-window
                                                window-tree
                                                horizontal-p)
  (let ((window-list (window-tree-flatten window-tree)))
    (if horizontal-p
        (cond ((< (window-x deleted-window)
                  (window-x (car window-list)))
               (dolist (win (lem-utils:min-if #'window-x window-list))
                 (window-set-pos win
                                 (window-x deleted-window)
                                 (window-y win))
                 (window-set-size win
                                  (+ (window-width deleted-window)
                                     1
                                     (window-width win))
                                  (window-height win))))
              (t
               (dolist (win (lem-utils:max-if #'window-x window-list))
                 (window-set-size win
                                  (+ (window-width deleted-window)
                                     1
                                     (window-width win))
                                  (window-height win)))))
        (cond ((< (window-y deleted-window)
                  (window-y (car window-list)))
               (dolist (win (lem-utils:min-if #'window-y window-list))
                 (window-set-pos win
                                 (window-x win)
                                 (window-y deleted-window))
                 (window-set-size win
                                  (window-width win)
                                  (+ (window-height deleted-window)
                                     (window-height win)))))
              (t
               (dolist (win (lem-utils:max-if #'window-y window-list))
                 (window-set-size win
                                  (window-width win)
                                  (+ (window-height deleted-window)
                                     (window-height win)))))))))

(defmethod %delete-window ((window window))
  (when (one-window-p)
    (editor-error "Can not delete this window"))
  (when (eq (current-window) window)
    (setf (current-window)
          (get-next-window (current-window))))
  (multiple-value-bind (node getter setter another-getter another-setter)
      (window-tree-parent (window-tree) window)
    (declare (ignore getter setter another-setter))
    (adjust-size-windows-after-delete-window
     window
     (funcall another-getter)
     (eq (window-node-split-type node) :hsplit))
    (multiple-value-bind (node2 getter2 setter2)
        (window-tree-parent (window-tree) node)
      (declare (ignore getter2))
      (if (null node2)
          (setf (window-tree) (funcall another-getter))
          (funcall setter2 (funcall another-getter))))))

(defun delete-window (window)
  (%delete-window window)
  (run-hooks (window-delete-hook window))
  (%free-window window)
  t)

(defun collect-left-windows (window-list)
  (lem-utils:min-if #'window-x window-list))

(defun collect-right-windows (window-list)
  (lem-utils:max-if (lambda (window)
                      (+ (window-x window)
                         (window-width window)))
                    window-list))

(defun collect-top-windows (window-list)
  (lem-utils:min-if #'window-y window-list))

(defun collect-bottom-windows (window-list)
  (lem-utils:max-if (lambda (window)
                      (+ (window-y window)
                         (window-height window)))
                    window-list))

(defun %shrink-windows (window-list
                        collect-windows-fn
                        check-fn
                        diff-height
                        diff-width
                        shift-height
                        shift-width)
  (let ((shrink-window-list
          (funcall collect-windows-fn window-list)))
    (dolist (window shrink-window-list)
      (when (not (funcall check-fn window))
        (return-from %shrink-windows nil)))
    (cond ((/= 0 diff-width)
           (dolist (window shrink-window-list)
             (window-resize window (- diff-width) 0)))
          ((/= 0 diff-height)
           (dolist (window shrink-window-list)
             (window-resize window 0 (- diff-height)))))
    (cond ((/= 0 shift-width)
           (dolist (window shrink-window-list)
             (window-move window shift-width 0)))
          ((/= 0 shift-height)
           (dolist (window shrink-window-list)
             (window-move window 0 shift-height)))))
  t)

(defun shrink-top-windows (window-list n)
  (%shrink-windows window-list
                   #'collect-top-windows
                   (lambda (window)
                     (< 2 (window-height window)))
                   n 0 n 0))

(defun shrink-bottom-windows (window-list n)
  (%shrink-windows window-list
                   #'collect-bottom-windows
                   (lambda (window)
                     (< 2 (window-height window)))
                   n 0 0 0))

(defun shrink-left-windows (window-list n)
  (%shrink-windows window-list
                   #'collect-left-windows
                   (lambda (window)
                     (< 2 (window-width window)))
                   0 n 0 n))

(defun shrink-right-windows (window-list n)
  (%shrink-windows window-list
                   #'collect-right-windows
                   (lambda (window)
                     (< 2 (window-width window)))
                   0 n 0 0))

(defun %grow-windows (window-list
                      collect-windows-fn
                      diff-height
                      diff-width
                      shift-height
                      shift-width)
  (dolist (window (funcall collect-windows-fn window-list))
    (cond ((/= 0 shift-width)
           (window-move window shift-width 0))
          ((/= 0 shift-height)
           (window-move window 0 shift-height)))
    (cond ((/= 0 diff-width)
           (window-resize window diff-width 0))
          ((/= 0 diff-height)
           (window-resize window 0 diff-height))))
  t)

(defun grow-top-windows (window-list n)
  (%grow-windows window-list
                 #'collect-top-windows
                 n 0 (- n) 0))

(defun grow-bottom-windows (window-list n)
  (%grow-windows window-list
                 #'collect-bottom-windows
                 n 0 0 0))

(defun grow-left-windows (window-list n)
  (%grow-windows window-list
                 #'collect-left-windows
                 0 n 0 (- n)))

(defun grow-right-windows (window-list n)
  (%grow-windows window-list
                 #'collect-right-windows
                 0 n 0 0))

(defun grow-window-internal (grow-window-list shrink-window-list n)
  (if (< (window-y (car grow-window-list))
         (window-y (car shrink-window-list)))
      (and (shrink-top-windows shrink-window-list n)
           (grow-bottom-windows grow-window-list n))
      (and (shrink-bottom-windows shrink-window-list n)
           (grow-top-windows grow-window-list n))))

(defun grow-window-horizontally-internal
    (grow-window-list shrink-window-list n)
  (if (< (window-x (car grow-window-list))
         (window-x (car shrink-window-list)))
      (and (shrink-left-windows shrink-window-list n)
           (grow-right-windows grow-window-list n))
      (and (shrink-right-windows shrink-window-list n)
           (grow-left-windows grow-window-list n))))

(defun resize-window-recursive (node n apply-fn split-type)
  (multiple-value-bind (parent-node
                        getter
                        setter
                        another-getter
                        another-setter)
      (window-tree-parent (window-tree) node)
    (declare (ignore setter another-setter))
    (cond ((null parent-node) nil)
          ((eq split-type (window-node-split-type parent-node))
           (funcall apply-fn
                    (window-tree-flatten (funcall getter))
                    (window-tree-flatten (funcall another-getter))
                    n))
          (t
           (resize-window-recursive parent-node n apply-fn split-type)))))

(defun adjust-windows (frame-x frame-y frame-width frame-height)
  (let ((window-list (window-list)))
    (let ((old-frame-x (window-x (first (collect-left-windows window-list))))
          (old-frame-y (window-y (first (collect-top-windows window-list)))))
      (dolist (window window-list)
        (window-set-pos window
                        (+ (window-x window) (- frame-x old-frame-x))
                        (+ (window-y window) (- frame-y old-frame-y))))
      (let ((delete-windows '()))
        (dolist (window window-list)
          (cond ((<= frame-height (+ 2 (window-y window)))
                 (push window delete-windows))
                ((<= frame-width (+ 1 (window-x window)))
                 (push window delete-windows))))
        (dolist (window delete-windows)
          (when (one-window-p) (return))
          (delete-window window)))))
  (let ((window-list (window-list)))
    (dolist (window (collect-right-windows window-list))
      (window-resize window
                     (- frame-width
                        (+ (window-x window) (window-width window)))
                     0))
    (dolist (window (collect-bottom-windows window-list))
      (window-resize window
                     0
                     (- frame-height
                        (+ (window-y window) (window-height window)))))))

(defun get-buffer-windows (buffer &key (frame (current-frame))
                                       (include-floating-windows nil))
  (loop :for window :in (append (window-list frame)
                                (when include-floating-windows
                                  (frame-floating-windows frame)))
        :when (eq buffer (window-buffer window))
        :collect window))

(defun other-buffer ()
  (let ((buffer-list (buffer-list)))
    (dolist (win (window-list))
      (setq buffer-list
            (remove (window-buffer win)
                    buffer-list)))
    (if (null buffer-list)
        (car (buffer-list))
        (car buffer-list))))

(defun run-show-buffer-hooks (window)
  (when (window-parameter window 'change-buffer)
    (setf (window-parameter window 'change-buffer) nil)
    (run-hooks *window-show-buffer-functions* window)))

(defun %switch-to-buffer (buffer record move-prev-point)
  (without-interrupts
    (unless (eq (current-buffer) buffer)
      (when record
        (setf (window-parameter (current-window) 'split-p) nil)
        (setf (window-parameter (current-window) 'parent-window) nil)
        (let ((old-buffer (current-buffer)))
          (unbury-buffer old-buffer)
          (%buffer-clear-keep-binfo old-buffer)
          (setf (%buffer-keep-binfo old-buffer)
                (list (copy-point (window-view-point (current-window)) :right-inserting)
                      (copy-point (window-buffer-point (current-window)) :right-inserting)))))
      (set-window-buffer buffer (current-window))
      (setf (current-buffer) buffer)
      (delete-point (%window-point (current-window)))
      (delete-point (window-view-point (current-window)))
      (cond ((and (%buffer-keep-binfo buffer) move-prev-point)
             (destructuring-bind (view-point cursor-point)
                 (%buffer-keep-binfo buffer)
               (set-window-view-point (copy-point view-point) (current-window))
               (set-window-point (copy-point cursor-point) (current-window))
               (move-point (buffer-point (current-buffer)) cursor-point)))
            (t
             (set-window-point (copy-point (buffer-start-point buffer) :right-inserting)
                               (current-window))
             (set-window-view-point (copy-point (buffer-start-point buffer) :right-inserting)
                                    (current-window)))))
    (setf (window-parameter (current-window) 'change-buffer) t))
  buffer)

(let ((key '#:not-switchable-buffer-p))
  (defun not-switchable-buffer-p (buffer)
    (buffer-value buffer key))

  (defun (setf not-switchable-buffer-p) (value buffer)
    (setf (buffer-value buffer key) value)))

(defun switch-to-buffer (buffer &optional (record t) (move-prev-point t))
  (check-type buffer buffer)
  (when (deleted-buffer-p buffer)
    (editor-error "This buffer has been deleted"))
  (when (or (not-switchable-buffer-p (window-buffer (current-window)))
            (not-switchable-buffer-p buffer))
    (editor-error "This buffer is not switchable"))
  (run-hooks (window-switch-to-buffer-hook (current-window)) buffer)
  (%switch-to-buffer buffer record move-prev-point))

(defun pop-to-buffer (buffer &optional force-split-p)
  (if (eq buffer (current-buffer))
      (return-from pop-to-buffer (values (current-window) nil))
      (let ((parent-window (current-window))
            (split-p))
        (let ((dst-window
                (if (frame-prompt-active-p (current-frame))
                    (frame-caller-of-prompt-window (current-frame))
                    (current-window))))
          (when (or (one-window-p) force-split-p)
            (setf split-p t)
            (split-window-sensibly dst-window))
          (with-current-window
              (or (window-tree-find-if (window-tree)
                                       (lambda (window)
                                         (eq buffer (window-buffer window))))
                  (get-next-window dst-window))
            (switch-to-buffer buffer)
            (setf (window-parameter (current-window) 'split-p) split-p)
            (setf (window-parameter (current-window) 'parent-window) parent-window)
            (values (current-window) split-p))))))

(defun difference-window-y (window)
  (lambda (w1 w2)
    (< (abs (- (window-y window) (window-y w1)))
       (abs (- (window-y window) (window-y w2))))))

(defun difference-window-x (window)
  (lambda (w1 w2)
    (< (abs (- (window-x window) (window-x w1)))
       (abs (- (window-x window) (window-x w2))))))

(defun left-window (window)
  (unless (floating-window-p window)
    (first (sort (remove-if-not (lambda (w)
                                  (and (<= (window-y w)
                                           (window-y window)
                                           (+ (window-y w) (window-height w) -1))
                                       (< (window-x w)
                                          (window-x window))))
                                (window-list))
                 #'>
                 :key #'window-x))))

(defun right-window (window)
  (unless (floating-window-p window)
    (first (sort (lem-utils:min-if #'window-x
                                   (remove-if-not (lambda (w)
                                                    (> (window-x w)
                                                       (+ (window-x window)
                                                          (window-width window))))
                                                  (window-list)))
                 (difference-window-y window)))))

(defun up-window (window)
  (unless (floating-window-p window)
    (first (sort (remove-if-not (lambda (w)
                                  (and (<= (window-x w)
                                           (window-x window)
                                           (+ (window-x w) (window-width w) -1))
                                       (< (window-y w)
                                          (window-y window))))
                                (window-list))
                 #'>
                 :key #'window-y))))

(defun down-window (window)
  (unless (floating-window-p window)
    (first (sort (lem-utils:min-if #'window-y
                                   (remove-if-not (lambda (w)
                                                    (>= (window-y w)
                                                        (+ (window-y window)
                                                           (window-height window))))
                                                  (window-list)))
                 (difference-window-x window)))))

(defclass floating-window (window)
  ((border
    :initarg :border
    :initform 0
    :reader floating-window-border)))

(defmethod initialize-instance :before ((floating-window floating-window) &rest initargs)
  (declare (ignore initargs))
  (unless (support-floating-window (implementation))
    (error "floating window is not supported"))
  (notify-floating-window-modified (current-frame)))

(defmethod initialize-instance :after ((floating-window floating-window)
                                       &key (frame (current-frame)) &allow-other-keys)
  (alexandria:appendf (frame-floating-windows frame)
                      (list floating-window)))

(defun make-floating-window (&key (buffer (alexandria:required-argument :buffer))
                                  (x (alexandria:required-argument :x))
                                  (y (alexandria:required-argument :y))
                                  (width (alexandria:required-argument :width))
                                  (height (alexandria:required-argument :height))
                                  (use-modeline-p nil))
  (make-instance 'floating-window
                 :buffer buffer
                 :x x
                 :y y
                 :width width
                 :height height
                 :use-modeline-p use-modeline-p))

(defmethod %delete-window ((window floating-window))
  (when (eq window (current-window))
    (editor-error "Can not delete this window"))
  (notify-floating-window-modified (current-frame))
  (setf (frame-floating-windows (current-frame))
        (delete window (frame-floating-windows (current-frame)))))

(defun floating-window-p (window)
  (typep window 'floating-window))

(defclass header-window (window) ())

(defmethod initialize-instance ((window header-window) &key &allow-other-keys)
  (with-slots (x y width height) window
    (setf x 0)
    (setf y (length (frame-header-windows (current-frame))))
    (setf width (display-width))
    (setf height 1))
  (add-header-window (current-frame) window)
  (notify-header-window-modified (current-frame))
  (call-next-method))

(defmethod %delete-window ((window header-window))
  (remove-header-window (current-frame) window)
  (notify-header-window-modified (current-frame)))

(defun adjust-all-window-size ()
  (dolist (window (frame-header-windows (current-frame)))
    (window-set-size window (display-width) 1))
  (adjust-windows (topleft-window-x (current-frame))
                  (topleft-window-y (current-frame))
                  (+ (max-window-width (current-frame)) (topleft-window-x (current-frame)))
                  (+ (max-window-height (current-frame)) (topleft-window-y (current-frame)))))

(defun change-display-size-hook ()
  (adjust-all-window-size)
  (clear-screens-of-window-list)
  (redraw-display))

(defvar *in-redraw-display* nil
  "この変数がTの場合、redraw-display関数で画面を描画中であることを表します。
再帰的なredraw-displayの呼び出しを防ぐために用います。")

(defun redraw-display (&optional force)
  (when *in-redraw-display*
    (log:warn "redraw-display is called recursively")
    (return-from redraw-display))
  (let ((*in-redraw-display* t))
    (labels ((redraw-window-list (force)
               (dolist (window (window-list))
                 (unless (eq window (current-window))
                   (window-redraw window force)))
               (window-redraw (current-window) force))
             (redraw-header-windows (force)
               (dolist (window (frame-header-windows (current-frame)))
                 (window-redraw window force)))
             (redraw-floating-windows ()
               (dolist (window (frame-floating-windows (current-frame)))
                 (window-redraw window (redraw-after-modifying-floating-window (implementation)))))
             (redraw-all-windows ()
               (redraw-header-windows force)
               (redraw-window-list
                (or (frame-require-redisplay-windows (current-frame))
                    (and (redraw-after-modifying-floating-window (implementation))
                         (or
                          ;; floating-windowが変更されたら、その下のウィンドウは再描画する必要がある
                          (frame-modified-floating-windows (current-frame))
                          ;; floating-windowが存在するときは常にその下のウィンドウは再描画する
                          ;; 例えば、promptの表示中に文字の削除などでpromptが縮小した場合に
                          ;; その下のウィンドウを再描画しないとpromptの枠が残ってしまう
                          (not (null (frame-floating-windows (current-frame))))))
                    force))
               (redraw-floating-windows)
               (lem-if:update-display (implementation))))
      (without-interrupts
        (when (frame-floating-prompt-window (current-frame))
          (update-prompt-window (frame-floating-prompt-window (current-frame))))
        (when (frame-modified-header-windows (current-frame))
          (adjust-all-window-size))
        (redraw-all-windows)
        (notify-frame-redraw-finished (current-frame))))))

(defun display-popup-message (buffer-or-string
                              &key (timeout *default-popup-message-timeout*)
                                   (gravity :cursor)
                                   destination-window)
  (lem-if:display-popup-message (implementation)
                                buffer-or-string
                                :timeout timeout
                                :gravity gravity
                                :destination-window destination-window))

(defun delete-popup-message (popup-message)
  (lem-if:delete-popup-message (implementation) popup-message))

(defun covered-with-floating-window-p (window x y)
  (let ((x (+ x (window-x window)))
        (y (+ y (window-y window))))
    (dolist (w (frame-floating-windows (current-frame)))
      (when (and (not (eq w window))
                 (<= (window-x w) x (+ (window-x w) (window-width w) -1))
                 (<= (window-y w) y (+ (window-y w) (window-height w) -1)))
        (return t)))))

(defun convert-window-n-tree (node)
  (labels ((join-children (node child)
             (cond ((windowp child)
                    (list child))
                   ((and (window-node-p child)
                         (eq (window-node-split-type node)
                             (window-node-split-type child)))
                    (rec child))
                   (t
                    (list (convert-window-n-tree child)))))
           (rec (node)
             (cond ((windowp node)
                    (list node))
                   (t
                    (append (join-children node (window-node-car node))
                            (join-children node (window-node-cdr node)))))))
    (if (windowp node)
        node
        (cons (window-node-split-type node)
              (rec node)))))

(defun balance-windows ()
  (labels ((rec (node x y width height)
             (cond ((windowp node)
                    (window-set-size node width height)
                    (window-set-pos node x y))
                   (t
                    (destructuring-bind (split-type &rest children) node
                      (let ((n (length children)))
                        (ecase split-type
                          (:hsplit
                           (multiple-value-bind (child-width remaining) (floor width n)
                             (loop :with rest-width := width
                                   :for (child . rest-children) :on children
                                   :for first := t :then nil
                                   :do (let ((child-width child-width))
                                         (cond ((null rest-children)
                                                (setf child-width rest-width))
                                               ((plusp remaining)
                                                (decf remaining)
                                                (incf child-width)))
                                         (rec child
                                              x
                                              y
                                              (if (null rest-children)
                                                  child-width
                                                  (- child-width *window-left-margin*))
                                              height)
                                         (incf x child-width)
                                         (decf rest-width child-width)))))
                          (:vsplit
                           (multiple-value-bind (child-height rem) (floor height n)
                             (loop :with rest-height := height
                                   :for (child . rest-children) :on children
                                   :do (let ((child-height child-height))
                                         (cond ((null rest-children)
                                                (setf child-height rest-height))
                                               ((plusp rem)
                                                (decf rem)
                                                (incf child-height)))
                                         (rec child
                                              x
                                              y
                                              width
                                              child-height)
                                         (incf y child-height)
                                         (decf rest-height child-height))))))))))))
    (rec (convert-window-n-tree (window-tree))
         (topleft-window-x (current-frame))
         (topleft-window-y (current-frame))
         (max-window-width (current-frame))
         (max-window-height (current-frame)))))
