(require 'package)
(setq package-enable-at-startup nil)

(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)

(package-initialize)

(setq custom-file "~/.emacs.d/emacs-custom.el")
(load custom-file)

(org-babel-load-file (expand-file-name "~/.emacs.d/config.org"))
