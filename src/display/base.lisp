(in-package :lem-core)

(defvar *inactive-window-background-color* nil)

(defun inactive-window-background-color ()
  *inactive-window-background-color*)

(defun (setf inactive-window-background-color) (color)
  (setf *inactive-window-background-color* color))

(defgeneric redraw-buffer (implementation buffer window force))

(defgeneric compute-left-display-area-content (mode buffer point)
  (:method (mode buffer point) nil))

(defvar *in-redraw-display* nil
  "この変数がTの場合、redraw-display関数で画面を描画中であることを表します。
再帰的なredraw-displayの呼び出しを防ぐために用います。")

(defgeneric window-redraw (window force)
  (:method (window force)
    (redraw-buffer (implementation) (window-buffer window) window force)))

(defun redraw-current-window (window force)
  (assert (eq window (current-window)))
  (window-see window)
  (run-show-buffer-hooks window)
  (window-redraw window force))

(defun redraw-display (&key force)
  (when *in-redraw-display*
    (log:warn "redraw-display is called recursively")
    (return-from redraw-display))
  (let ((*in-redraw-display* t))
    (labels ((redraw-window-list (force)
               (dolist (window (window-list))
                 (unless (eq window (current-window))
                   (window-redraw window force)))
               (redraw-current-window (current-window) force))
             (redraw-header-windows (force)
               (dolist (window (frame-header-windows (current-frame)))
                 (window-redraw window force)))
             (redraw-floating-windows ()
               (dolist (window (frame-floating-windows (current-frame)))
                 (window-redraw window (redraw-after-modifying-floating-window (implementation)))))
             (redraw-all-windows ()
               (redraw-header-windows force)
               (redraw-window-list
                (if (redraw-after-modifying-floating-window (implementation))
                    (or (frame-require-redisplay-windows (current-frame))
                        ;; floating-windowが変更されたら、その下のウィンドウは再描画する必要がある
                        (frame-modified-floating-windows (current-frame))
                        force)
                    force))
               (redraw-floating-windows)
               (lem-if:update-display (implementation))))
      (without-interrupts
        (lem-if:will-update-display (implementation))
        (update-floating-prompt-window (current-frame))
        (when (frame-modified-header-windows (current-frame))
          (adjust-all-window-size))
        (redraw-all-windows)
        (notify-frame-redraw-finished (current-frame))))))
