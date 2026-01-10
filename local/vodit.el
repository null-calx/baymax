;;; vodit.el --- minor mode to run org src blocks directly on local or remote systems

;; This is free and unencumbered software released into the public domain.
;; For more information, please refer to <https://unlicense.org/>

;; Author: calx
;; URL: https://raw.githubusercontent.com/null-calx/baymax/refs/heads/master/local/vodit.el
;; URL: https://istaroth.org/files/vodit.el
;; Version: 1.0.0

;;; Commentary:

;; A minor mode to run org src blocks directly on local or remote
;; systems.

(require 'org)

(defvar vodit--temp-buffer-name "*vodit-output*")

(defmacro vodit--with-tmpfile (arguments &rest body)
  (cl-destructuring-bind (tmpfile-var prefix &optional dir-flag suffix text)
      arguments
    (let ((dir-flag-var (gensym)))
      `(let* ((,dir-flag-var ,dir-flag)
              (,tmpfile-var (make-temp-file ,prefix ,dir-flag ,suffix ,text)))
         (unwind-protect
             (progn ,@body)
           (if ,dir-flag-var
               (when (file-directory-p ,tmpfile-var)
                 (delete-directory ,tmpfile-var t))
             (when (file-exists-p ,tmpfile-var)
               (delete-file ,tmpfile-var))))))))

(defun vodit--create-ssh-args (host port root user interpreter)
  (let ((args (list host "-p" (format "%d" port))))
    (when user
      (setf args (append args (list "-l" user))))
    (setf args (append args (list "--")))
    (when root
      (setf args (append args (list "sudo"))))
    (setf args (append args (list interpreter)))
    args))

(defun vodit--process (src-block vodit-args)
  (let* ((body (nth 1 src-block))
              (host (plist-get vodit-args :host))
              (port (plist-get vodit-args :port))
              (root (plist-get vodit-args :root))
              (user (plist-get vodit-args :user))
              (interpreter (plist-get vodit-args :interpreter)))
    (cond
     ((string-equal host "localhost")
      (vodit--with-tmpfile (src-content "vodit-src-content" nil ".txt" body)
         (call-process "env" 
                       src-content
                       vodit--temp-buffer-name
                       t
                       "-S"
                       interpreter)))
     (t
      (vodit--with-tmpfile (src-content "vodit-src-content" nil ".txt" body)
         (apply #'call-process 
                "ssh"
                src-content
                vodit--temp-buffer-name
                t
                (vodit--create-ssh-args host port root user interpreter)))))))

(defun vodit--fetch-src-block-at-point ()
  (when (org-in-src-block-p)
    (let* ((elm (org-element-at-point))
           (type (org-element-type elm)))
      (when (eq type 'src-block)
        (org-babel-get-src-block-info t elm)))))

(defun vodit--fetch-vodit-args (src-block)
  (when-let* ((args (nth 2 src-block))
              (vodit (cdr (assoc :vodit args))))
    (list :vodit vodit
          :host (or (cdr (assoc :vodit-remote-host args))
                    (org-entry-get nil "vodit-remote-host" t))
          :port (or (cdr (assoc :vodit-remote-port args))
                    (org-entry-get nil "vodit-remote-port" t)
                    22)
          :root (or (cdr (assoc :vodit-remote-root args))
                    (org-entry-get nil "vodit-remote-root" t))
          :user (or (cdr (assoc :vodit-remote-user args))
                    (org-entry-get nil "vodit-remote-user" t))
          :interpreter (or (cdr (assoc :vodit-interpreter args))
                           (org-entry-get nil "vodit-interpreter" t)
                           "bash"))))

(defun vodit--handler ()
  "vodit-mode ctrl-c-ctrl-c handler"
  (when-let* ((src-block (vodit--fetch-src-block-at-point))
              (vodit-args (vodit--fetch-vodit-args src-block))
              (vodit (plist-get vodit-args :vodit))
              (host (plist-get vodit-args :host)))
    (with-output-to-temp-buffer vodit--temp-buffer-name
      (let ((pr (make-progress-reporter (if (string-equal host "localhost")
                                            "voditing"
                                            (format "voditing into %s" host)))))
        (display-buffer vodit--temp-buffer-name)
        (vodit--process src-block vodit-args)
        (progress-reporter-done pr)))
    t))

;;;###autoload
(define-minor-mode vodit-mode
  "vodit-mode"
  :lighter " Vodit"
  :require 'org
  (if vodit-mode
      (add-hook 'org-ctrl-c-ctrl-c-hook 'vodit--handler nil t)
    (remove-hook 'org-ctrl-c-ctrl-c-hook 'vodit--handler t)))

(provide 'vodit-mode)

;;; vodit.el ends here
