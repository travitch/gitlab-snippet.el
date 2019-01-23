;;; gitlab-snippet.el --- A package for posting code as Gitlab snippets    -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Tristan Ravitch

;; Author: Tristan Ravitch <tristan.ravitch@gmail.com>
;; Keywords: gitlab
;; Version: 0.0.1

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;;  Commentary:

;; This package implements an interface for posting code snippets (either
;; buffers or the active region) to Gitlab as snippets.
;;
;; The main entry point is `gitlab-snippet-region`, which will post the active
;; region (if any) or the current buffer to Gitlab as a snippet.  You must set
;; `gitlab-snippet-host` and `gitlab-snippet-api-token` in order for it to work.
;;
;; The URL for the snippet is shown in a fresh buffer.  You can dismiss that
;; buffer with 'q'.

;;; Code:

(defvar gitlab-snippet-host nil
  "The host to which snippets should be POST-ed.")

(defvar gitlab-snippet-api-token nil
  "The API token to authenticate snippets with the Gitlab server.")

;;;###autoload
(defun gitlab-snippet-region ()
  "Post the current active region (or buffer if there is none) to Gitlab.

It currently only works under Linux, as it uses the Secret Service API to store
a Gitlab API key."
  (interactive)
  (let* ((start (if mark-active (region-beginning) (point-min)))
         (end (if mark-active (region-end) (point-max)))
         (content (buffer-substring-no-properties start end)))
    (gitlab-snippet--post gitlab-snippet-host gitlab-snippet-api-token (buffer-name) content)))

(defun gitlab-snippet--post (root token filename content)
  "Post a string CONTENTS (nominally from a file named FILENAME) to a Gitlab snippets instance (available at ROOT via service key TOKEN).

The URL for the snippet is extracted from the Gitlab response and shown in a buffer."
  (require 'json)
  (require 'request)
  (request (format "%s/api/v4/snippets" root)
           :type "POST"
           :parser 'json-read
           :data (json-encode `(("file_name" . ,filename)
                                ("title" . ,filename)
                                ("visibility" . "internal")
                                ("content" . ,content)))
           :headers `(("Content-Type" . "application/json")
                      ("PRIVATE-TOKEN" . ,token))
           :success
           (cl-function (lambda (&key data &allow-other-keys)
                          (when data
                            (with-current-buffer (generate-new-buffer "*gitlab-snippet*")
                              (insert (cdr (assoc 'web_url data)))
                              (special-mode)
                              (pop-to-buffer (current-buffer))))))
           :error
           (cl-function (lambda (&key error-thrown &allow-other-keys&rest _)
                        (message "Got error: %S" error-thrown)))))

(provide 'gitlab-snippet)
;;; gitlab-snippet.el ends here
