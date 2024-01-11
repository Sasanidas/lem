(defpackage :lem/simple-package
  (:use :cl :lem))

(in-package :lem/simple-package)

(defparameter *installed-packages* nil)

(defparameter *packages-directory*
  (pathname (str:concat
             (directory-namestring (lem-home))
             "packages"
             (string  (uiop:directory-separator-for-host)))))

(defstruct source name)

(defgeneric download-source (source output-location)
  (:documentation "It downloads the SOURCE to the desired location."))

;; From porcelain.lisp
(defvar *git-base-arglist* (list "git")
  "The git program, to be appended command-line options.")

(defun run-git (arglist)
  (uiop:wait-process
   (uiop:launch-program (concatenate 'list *git-base-arglist* arglist)
                        :ignore-error-status t)))

(defstruct (git (:include source)) url branch commit)

(defmethod download-source ((source git) (output-location String))
  (let ((output-dir (str:concat
                     (namestring *packages-directory*) output-location)))
    (run-git (list "clone" (git-url source) output-dir))
    (when (git-branch source)
      (uiop:with-current-directory (output-dir)
        (run-git (list "checkout" "-b" (git-branch source)))))

    (when (git-commit source)
      (uiop:with-current-directory (output-dir)
        (run-git (list "checkout" (git-commit source)))))
    output-dir))

(defstruct (quicklisp (:include source)))

(eval-when (:compile-toplevel)
  (defparameter *quicklisp-system-list*
    (remove-duplicates
     (mapcar #'ql-dist:release (ql:system-list)))))

(defmethod download-source ((source quicklisp) (output-location String))
  (let* ((output-dir (str:concat
                     (namestring *packages-directory*) output-location))
         (release (find (source-name source)
                       *quicklisp-system-list*
                       :key #'ql-dist:project-name
                       :test #'string=))
         (url (ql-dist:archive-url release))
         (name (source-name source))
         (tgzfile (str:concat name ".tgz"))
         (tarfile (str:concat name ".tar")))
    (if release
        (prog1 output-dir
          (uiop:with-current-directory (*packages-directory*)
            (quicklisp-client::maybe-fetch-gzipped url tgzfile
                                                   :quietly t)
            (ql-gunzipper:gunzip tgzfile tarfile)
            (ql-minitar:unpack-tarball tarfile)
            (delete-file tgzfile)
            (delete-file tarfile)
            (uiop/cl:rename-file (ql-dist:prefix release) output-location)))
        (editor-error "Package ~a not found!." (source-name source)))))

(defmethod download-source (source output-location)
  (editor-error "Source ~a not available." source))

(defclass simple-package ()
  ((name :initarg :name
         :accessor simple-package-name)
   (source :initarg :source
           :accessor simple-package-source)
   (directory :initarg :directory
              :accessor simple-package-directory)))

(defgeneric package-remove (package))

(defmethod package-remove ((package simple-package))
  (uiop:delete-directory-tree
   (uiop:truename* (simple-package-directory package)) :validate t)
  (delete package *installed-packages*))

(defun packages-list ()
  (remove-duplicates
   (mapcar #'(lambda (d) (pathname (directory-namestring d)))
           (directory (merge-pathnames "**/*.asd" *packages-directory*)))))

(defun insert-package (package)
  (pushnew package *installed-packages*
           :test #'(lambda (a b)
                     (string=
                      (simple-package-name a)
                      (simple-package-name b)))))

;; git source (list :type type :url url :branch branch :commit commit)
(defmacro lem-use-package (name &key source config
                                 after bind
                                 hooks force)
  (declare (ignore hooks bind after config ))
  (alexandria:with-gensyms (spackage rsource pdir)
    `(labels ((dfsource (source-list)
                (let ((s (getf source-list :type)))
                  (ecase s
                    (:git
                     (destructuring-bind (&key type url branch commit)
                         source-list
                       (declare (ignore type))
                       (make-git :name ,name
                                 :url url
                                 :branch branch
                                 :commit commit)))
                    (:quicklisp
                     (destructuring-bind (&key type)
                         source-list
                       (declare (ignore type))
                       (make-quicklisp :name ,name)))
                    (t (editor-error "Source ~a not available." s))))))
       (let* ((asdf:*central-registry*
                (union (packages-list)
                       asdf:*central-registry*
                       :test #'equal))
              (ql:*local-project-directories*
                (nconc (list *packages-directory*)
                       ql:*local-project-directories*))
              (,rsource (dfsource ,source))
              (,pdir (merge-pathnames *packages-directory* ,name))
              (,spackage (make-instance 'simple-package
                                        :name ,name
                                        :source ,rsource
                                        :directory ,pdir)))
         (when (or ,force
                   (not (uiop:directory-exists-p ,pdir)))
           (message "Downloading ~a..." ,name)
           (download-source ,rsource ,name)
           (message "Done downloading ~a!" ,name))

         (insert-package ,spackage)
         (uiop:symbol-call :quicklisp :register-local-projects)
         (maybe-quickload (alexandria:make-keyword ,name)
                          :silent t)))))

;(lem-use-package "versioned-objects"
;                 :source '(:type :git
;                           :url "https://github.com/smithzvk/Versioned-Objects.git"
;                           :branch "advance-versioning"))

;(lem-use-package "fiveam" :source (:type :quicklisp))

;; Package util commands

(defun load-packages ()
  (let ((ql:*local-project-directories* (list *packages-directory*)))
    (loop for dpackage in (directory (merge-pathnames "*/" *packages-directory*))
          for spackage = (car
                          (last
                           (pathname-directory
                            (uiop:directorize-pathname-host-device dpackage))))
          do (insert-package
              (make-instance 'simple-package
                             :name spackage
                             :source (make-local :name spackage)
                             :directory dpackage))
          do (maybe-quickload (alexandria:make-keyword spackage) :silent t))))

(define-command simple-package-install-ql-package () ()
  (let* ((packages (mapcar #'ql-dist:project-name
                           *quicklisp-system-list*))
         (rpackage
           (prompt-for-string "Select package: "
                              :completion-function
                              (lambda (string)
                                (completion string packages)))))

    (lem-use-package rpackage :source '(:type :quicklisp))
    (message "Package ~a installed!" rpackage)))

(define-command simple-package-remove-package () ()
  (if *installed-packages*
      (let* ((packages (and *installed-packages*
                            (mapcar #'simple-package-name
                                    *installed-packages*)))
             (rpackage
               (prompt-for-string "Select package: "
                                  :completion-function
                                  (lambda (string)
                                    (completion string packages)))))
        (package-remove
         (find rpackage *installed-packages*
               :key #'simple-package-name
               :test #'string=))
        (message "Package remove from system!"))

      (message "No packages installed!")))
