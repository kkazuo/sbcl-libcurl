#|
Copyright (c) 2024 Koga Kazuo <kogakazuo@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
|#

#|

SBCL の外部関数呼び出し機能を使って libcurl で HTTP リクエストしてみる実験。

以下で動くと思う。

% sbcl --load sbcl-libcurl.lisp --eval '(sbcl-libcurl::xxx)' --no-userinit --non-interactive

確かにデータは取れるので、頑張ればいろいろできるのだろうとは思うが、面倒になって途中でめげてしまった。

|#

(cl:defpackage "SBCL-LIBCURL"
  (:use "CL" "SB-ALIEN" "SB-C-CALL"))
(cl:in-package "SBCL-LIBCURL")

(load-shared-object
 #+linux "libcurl.so"
 #+darwin "libcurl.dylib"
 #-(or linux darwin) "UNSUPPORTED")

(defconstant CURLOPTTYPE_LONG          0)
(defconstant CURLOPTTYPE_OBJECTPOINT   10000)
(defconstant CURLOPTTYPE_FUNCTIONPOINT 20000)
(defconstant CURLOPTTYPE_OFF_T         30000)
(defconstant CURLOPTTYPE_BLOB          40000)

(defconstant CURLOPTTYPE_STRINGPOINT CURLOPTTYPE_OBJECTPOINT)
(defconstant CURLOPTTYPE_SLISTPOINT  CURLOPTTYPE_OBJECTPOINT)
(defconstant CURLOPTTYPE_CBPOINT     CURLOPTTYPE_OBJECTPOINT)
(defconstant CURLOPTTYPE_VALUES      CURLOPTTYPE_LONG)

(defconstant CURLOPT_WRITEDATA          (+ CURLOPTTYPE_CBPOINT        1))
(defconstant CURLOPT_URL                (+ CURLOPTTYPE_STRINGPOINT    2))
(defconstant CURLOPT_USERPWD            (+ CURLOPTTYPE_STRINGPOINT    5))
(defconstant CURLOPT_WRITEFUNCTION      (+ CURLOPTTYPE_FUNCTIONPOINT 11))
(defconstant CURLOPT_TIMEOUT            (+ CURLOPTTYPE_LONG          13))
(defconstant CURLOPT_REFERER            (+ CURLOPTTYPE_STRINGPOINT   16))
(defconstant CURLOPT_USERAGENT          (+ CURLOPTTYPE_STRINGPOINT   18))
(defconstant CURLOPT_COOKIE             (+ CURLOPTTYPE_STRINGPOINT   22))
(defconstant CURLOPT_HTTPHEADER         (+ CURLOPTTYPE_SLISTPOINT    23))
(defconstant CURLOPT_HEADERDATA         (+ CURLOPTTYPE_CBPOINT       29))
(defconstant CURLOPT_CUSTOMREQUEST      (+ CURLOPTTYPE_STRINGPOINT   36))
(defconstant CURLOPT_VERBOSE            (+ CURLOPTTYPE_LONG          41))
(defconstant CURLOPT_HEADER             (+ CURLOPTTYPE_LONG          42))
(defconstant CURLOPT_NOPROGRESS         (+ CURLOPTTYPE_LONG          43))
(defconstant CURLOPT_NOBODY             (+ CURLOPTTYPE_LONG          44))
(defconstant CURLOPT_UPLOAD             (+ CURLOPTTYPE_LONG          46))
(defconstant CURLOPT_POST               (+ CURLOPTTYPE_LONG          47))
(defconstant CURLOPT_FOLLOWLOCATION     (+ CURLOPTTYPE_LONG          52))
(defconstant CURLOPT_AUTOREFERER        (+ CURLOPTTYPE_LONG          58))
(defconstant CURLOPT_POSTFIELDSIZE      (+ CURLOPTTYPE_LONG          60))
(defconstant CURLOPT_SSL_VERIFYPEER     (+ CURLOPTTYPE_LONG          64))
(defconstant CURLOPT_CAINFO             (+ CURLOPTTYPE_STRINGPOINT   65))
(defconstant CURLOPT_MAXREDIRS          (+ CURLOPTTYPE_LONG          68))
(defconstant CURLOPT_MAXCONNECTS        (+ CURLOPTTYPE_LONG          71))
(defconstant CURLOPT_CONNECTTIMEOUT     (+ CURLOPTTYPE_LONG          78))
(defconstant CURLOPT_HEADERFUNCTION     (+ CURLOPTTYPE_FUNCTIONPOINT 79))
(defconstant CURLOPT_SSL_VERIFYHOST     (+ CURLOPTTYPE_LONG          81))
(defconstant CURLOPT_NOSIGNAL           (+ CURLOPTTYPE_LONG          99))
(defconstant CURLOPT_UNRESTRICTED_AUTH  (+ CURLOPTTYPE_LONG         105))
(defconstant CURLOPT_HTTPAUTH           (+ CURLOPTTYPE_VALUES       107))
(defconstant CURLOPT_TCP_NODELAY        (+ CURLOPTTYPE_LONG         121))
(defconstant CURLOPT_USERNAME           (+ CURLOPTTYPE_STRINGPOINT  173))
(defconstant CURLOPT_PASSWORD           (+ CURLOPTTYPE_STRINGPOINT  174))
(defconstant CURLOPT_TCP_KEEPALIVE      (+ CURLOPTTYPE_LONG         213))
(defconstant CURLOPT_XOAUTH2_BEARER     (+ CURLOPTTYPE_STRINGPOINT  220))

(defconstant CURLAUTH_NONE             0)
(defconstant CURLAUTH_BASIC     (ash 1 0))
(defconstant CURLAUTH_DIGEST    (ash 1 1))
(defconstant CURLAUTH_NEGOTIATE (ash 1 2))
(defconstant CURLAUTH_NTLM      (ash 1 3))
(defconstant CURLAUTH_DIGEST_IE (ash 1 4))
(defconstant CURLAUTH_BEARER    (ash 1 6))
(defconstant CURLAUTH_AWS_SIGV4 (ash 1 7))

(define-alien-type curl-code
    (enum
     nil
     OK
     CURLE_UNSUPPORTED_PROTOCOL    ;; 1
     CURLE_FAILED_INIT             ;; 2
     CURLE_URL_MALFORMAT           ;; 3
     CURLE_NOT_BUILT_IN            ;; 4 - [was obsoleted in August 2007 for 7.17.0,
                                   ;;     reused in April 2011 for 7.21.5]
     CURLE_COULDNT_RESOLVE_PROXY   ;; 5
     CURLE_COULDNT_RESOLVE_HOST    ;; 6
     CURLE_COULDNT_CONNECT         ;; 7
     CURLE_WEIRD_SERVER_REPLY      ;; 8
     CURLE_REMOTE_ACCESS_DENIED    ;; 9 - a service was denied by the server due to lack of
                                   ;;     access - when login fails this is not returned.
     CURLE_FTP_ACCEPT_FAILED       ;; 10 - [was obsoleted in April 2006 for 7.15.4,
                                   ;;      reused in Dec 2011 for 7.24.0]
     CURLE_FTP_WEIRD_PASS_REPLY    ;; 11
     CURLE_FTP_ACCEPT_TIMEOUT      ;; 12 - timeout occurred accepting server
                                   ;;      [was obsoleted in August 2007 for 7.17.0,
                                   ;;      reused in Dec 2011 for 7.24.0]
     CURLE_FTP_WEIRD_PASV_REPLY    ;; 13
     CURLE_FTP_WEIRD_227_FORMAT    ;; 14
     CURLE_FTP_CANT_GET_HOST       ;; 15
     CURLE_HTTP2                   ;; 16 - A problem in the http2 framing layer.
                                   ;;      [was obsoleted in August 2007 for 7.17.0,
                                   ;;      reused in July 2014 for 7.38.0]
     CURLE_FTP_COULDNT_SET_TYPE    ;; 17
     CURLE_PARTIAL_FILE            ;; 18
     CURLE_FTP_COULDNT_RETR_FILE   ;; 19
     CURLE_OBSOLETE20              ;; 20 - NOT USED
     CURLE_QUOTE_ERROR             ;; 21 - quote command failure
     CURLE_HTTP_RETURNED_ERROR     ;; 22
     CURLE_WRITE_ERROR             ;; 23
     CURLE_OBSOLETE24              ;; 24 - NOT USED
     CURLE_UPLOAD_FAILED           ;; 25 - failed upload "command"
     CURLE_READ_ERROR              ;; 26 - could not open/read from file
     CURLE_OUT_OF_MEMORY           ;; 27
     CURLE_OPERATION_TIMEDOUT      ;; 28 - the timeout time was reached
     CURLE_OBSOLETE29              ;; 29 - NOT USED
     CURLE_FTP_PORT_FAILED         ;; 30 - FTP PORT operation failed
     CURLE_FTP_COULDNT_USE_REST    ;; 31 - the REST command failed
     CURLE_OBSOLETE32              ;; 32 - NOT USED
     CURLE_RANGE_ERROR             ;; 33 - RANGE "command" did not work
     CURLE_HTTP_POST_ERROR         ;; 34
     CURLE_SSL_CONNECT_ERROR       ;; 35 - wrong when connecting with SSL
     CURLE_BAD_DOWNLOAD_RESUME     ;; 36 - could not resume download
     CURLE_FILE_COULDNT_READ_FILE  ;; 37
     CURLE_LDAP_CANNOT_BIND        ;; 38
     CURLE_LDAP_SEARCH_FAILED      ;; 39
     CURLE_OBSOLETE40              ;; 40 - NOT USED
     CURLE_FUNCTION_NOT_FOUND      ;; 41 - NOT USED starting with 7.53.0
     CURLE_ABORTED_BY_CALLBACK     ;; 42
     CURLE_BAD_FUNCTION_ARGUMENT   ;; 43
     CURLE_OBSOLETE44              ;; 44 - NOT USED
     CURLE_INTERFACE_FAILED        ;; 45 - CURLOPT_INTERFACE failed
     CURLE_OBSOLETE46              ;; 46 - NOT USED
     CURLE_TOO_MANY_REDIRECTS      ;; 47 - catch endless re-direct loops
     CURLE_UNKNOWN_OPTION          ;; 48 - User specified an unknown option
     CURLE_SETOPT_OPTION_SYNTAX    ;; 49 - Malformed setopt option
     CURLE_OBSOLETE50              ;; 50 - NOT USED
     CURLE_OBSOLETE51              ;; 51 - NOT USED
     CURLE_GOT_NOTHING             ;; 52 - when this is a specific error
     CURLE_SSL_ENGINE_NOTFOUND     ;; 53 - SSL crypto engine not found
     CURLE_SSL_ENGINE_SETFAILED    ;; 54 - can not set SSL crypto engine as default
     CURLE_SEND_ERROR              ;; 55 - failed sending network data
     CURLE_RECV_ERROR              ;; 56 - failure in receiving network data
     CURLE_OBSOLETE57              ;; 57 - NOT IN USE
     CURLE_SSL_CERTPROBLEM         ;; 58 - problem with the local certificate
     CURLE_SSL_CIPHER              ;; 59 - could not use specified cipher
     CURLE_PEER_FAILED_VERIFICATION;; 60 - peer's certificate or fingerprint was not verified fine
     CURLE_BAD_CONTENT_ENCODING    ;; 61 - Unrecognized/bad encoding
     CURLE_OBSOLETE62              ;; 62 - NOT IN USE since 7.82.0
     CURLE_FILESIZE_EXCEEDED       ;; 63 - Maximum file size exceeded
     CURLE_USE_SSL_FAILED          ;; 64 - Requested FTP SSL level failed
     CURLE_SEND_FAIL_REWIND        ;; 65 - Sending the data requires a rewind that failed
     CURLE_SSL_ENGINE_INITFAILED   ;; 66 - failed to initialise ENGINE
     CURLE_LOGIN_DENIED            ;; 67 - user, password or similar was not accepted and
                                   ;;      we failed to login
     CURLE_TFTP_NOTFOUND           ;; 68 - file not found on server
     CURLE_TFTP_PERM               ;; 69 - permission problem on server
     CURLE_REMOTE_DISK_FULL        ;; 70 - out of disk space on server
     CURLE_TFTP_ILLEGAL            ;; 71 - Illegal TFTP operation
     CURLE_TFTP_UNKNOWNID          ;; 72 - Unknown transfer ID
     CURLE_REMOTE_FILE_EXISTS      ;; 73 - File already exists
     CURLE_TFTP_NOSUCHUSER         ;; 74 - No such user
     CURLE_OBSOLETE75              ;; 75 - NOT IN USE since 7.82.0
     CURLE_OBSOLETE76              ;; 76 - NOT IN USE since 7.82.0
     CURLE_SSL_CACERT_BADFILE      ;; 77 - could not load CACERT file, missing or wrong format
     CURLE_REMOTE_FILE_NOT_FOUND   ;; 78 - remote file not found
     CURLE_SSH                     ;; 79 - error from the SSH layer,
                                   ;;      somewhat generic so the error message will be of
                                   ;;      interest when this has happened
     CURLE_SSL_SHUTDOWN_FAILED     ;; 80 - Failed to shut down the SSL connection
     CURLE_AGAIN                   ;; 81 - socket is not ready for send/recv,
                                   ;;      wait till it is ready and try again (Added in 7.18.2)
     CURLE_SSL_CRL_BADFILE         ;; 82 - could not load CRL file,
                                   ;;      missing or wrong format (Added in 7.19.0)
     CURLE_SSL_ISSUER_ERROR        ;; 83 - Issuer check failed.  (Added in 7.19.0)
     CURLE_FTP_PRET_FAILED         ;; 84 - a PRET command failed
     CURLE_RTSP_CSEQ_ERROR         ;; 85 - mismatch of RTSP CSeq numbers
     CURLE_RTSP_SESSION_ERROR      ;; 86 - mismatch of RTSP Session Ids
     CURLE_FTP_BAD_FILE_LIST       ;; 87 - unable to parse FTP file list
     CURLE_CHUNK_FAILED            ;; 88 - chunk callback reported error
     CURLE_NO_CONNECTION_AVAILABLE ;; 89 - No connection available, the session will be queued
     CURLE_SSL_PINNEDPUBKEYNOTMATCH;; 90 - specified pinned public key did not match
     CURLE_SSL_INVALIDCERTSTATUS   ;; 91 - invalid certificate status
     CURLE_HTTP2_STREAM            ;; 92 - stream error in HTTP/2 framing layer
     CURLE_RECURSIVE_API_CALL      ;; 93 - an api function was called from inside a callback
     CURLE_AUTH_ERROR              ;; 94 - an authentication function returned an error
     CURLE_HTTP3                   ;; 95 - An HTTP/3 layer problem
     CURLE_QUIC_CONNECT_ERROR      ;; 96 - QUIC connection error
     CURLE_PROXY                   ;; 97 - proxy handshake error
     CURLE_SSL_CLIENTCERT          ;; 98 - client-side certificate required
     CURLE_UNRECOVERABLE_POLL      ;; 99 - poll/select returned fatal error
     CURLE_TOO_LARGE               ;; 100 - a value/data met its maximum
     CURLE_ECH_REQUIRED            ;; 101 - ECH tried but failed
     ))

(declaim (inline curl-easy-init))
(define-alien-routine curl-easy-init (* (struct curl)))

(declaim (inline curl-easy-perform))
(define-alien-routine curl-easy-perform curl-code
  (curl (* (struct curl))))

(declaim (inline curl-easy-cleanup))
(define-alien-routine curl-easy-cleanup void
  (curl (* (struct curl))))

;;; Creates a new curl session handle with the same options set for the handle
;;; passed in. Duplicating a handle could only be a matter of cloning data and
;;; options, internal state info and things like persistent connections cannot
;;; be transferred. It is useful in multithreaded applications when you can run
;;; curl_easy_duphandle() for each new thread to avoid a series of identical
;;; curl_easy_setopt() invokes in every thread.
(declaim (inline curl-easy-duphandle))
(define-alien-routine curl-easy-duphandle (* (struct curl))
  (curl (* (struct curl))))

;;; Re-initializes a CURL handle to the default values. This puts back the
;;; handle to the same state as it was in when it was just created.
;;;
;;; It does keep: live connections, the Session ID cache, the DNS cache and the
;;; cookies.
(declaim (inline curl-easy-reset))
(define-alien-routine curl-easy-reset void
  (curl (* (struct curl))))

;;; Performs connection upkeep for the given session handle.
(declaim (inline curl-easy-upkeep))
(define-alien-routine curl-easy-upkeep int
  (curl (* (struct curl))))

(declaim (inline curl-easy-setopt-long))
(define-alien-routine ("curl_easy_setopt" curl-easy-setopt-long) curl-code
  (curl (* (struct curl)))
  (opt int)
  (val long))

(declaim (inline curl-easy-setopt-string))
(define-alien-routine ("curl_easy_setopt" curl-easy-setopt-string) curl-code
  (curl (* (struct curl)))
  (opt int)
  (val c-string))

(declaim (inline curl-easy-setopt-pointer))
(define-alien-routine ("curl_easy_setopt" curl-easy-setopt-pointer) curl-code
  (curl (* (struct curl)))
  (opt int)
  (val (* t)))

(declaim (inline curl-easy-setopt-callback))
(define-alien-routine ("curl_easy_setopt" curl-easy-setopt-callback) curl-code
  (curl (* (struct curl)))
  (opt int)
  (val (function size-t (* char) long long (* t))))

(defvar *body-output* *standard-output*)
(defvar *header-output* *standard-output*)

(define-alien-callable write-body size-t
    ((ptr (* char)) (size long) (nmemb long) (userdata (* t)))
  (declare (ignore userdata))
  (let ((total (* size nmemb)))
    (dotimes (i total)
      (write-byte (deref ptr i) *body-output*))
    total))

(define-alien-callable write-header size-t
    ((ptr (* char)) (size long) (nmemb long) (userdata (* t)))
  (declare (ignore userdata))
  (let ((total (* size nmemb)))
    (dotimes (i total)
      (write-byte (deref ptr i) *header-output*))
    total))

(defun xxx ()
  (let ((h (curl-easy-init))
        (wb (alien-callable-function 'write-body))
        (wh (alien-callable-function 'write-header)))
    (sb-sys:with-pinned-objects (h wb wh)
      (curl-easy-setopt-string h CURLOPT_URL "http://httpbin.org/get")
      (curl-easy-setopt-string h CURLOPT_USERNAME "hello")
      (curl-easy-setopt-string h CURLOPT_PASSWORD "world")
      (curl-easy-setopt-string h CURLOPT_XOAUTH2_BEARER "this-is-my-token")
      (curl-easy-setopt-callback h CURLOPT_WRITEFUNCTION wb)
      (curl-easy-setopt-pointer h CURLOPT_WRITEDATA nil)
      (curl-easy-setopt-callback h CURLOPT_HEADERFUNCTION wh)
      (curl-easy-setopt-pointer h CURLOPT_HEADERDATA nil)
      (curl-easy-setopt-long h CURLOPT_HTTPAUTH CURLAUTH_BEARER)
      (curl-easy-perform h)
      (curl-easy-cleanup h))))

;(xxx)
