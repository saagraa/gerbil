;;; -*- Gerbil -*-
;;; (C) vyzo at hackzen.org
;;; Rack-style web servers with fastcgi connections
package: std/web

(import :gerbil/gambit
        :std/net/fastcgi
        :std/sugar
        :std/format
        :std/iter
        :std/error
        )
(export start-rack-fastcgi-server!)

;; handler is a function (env data) => (values status headers body)
;;  env is a hash symbol => string (fastcgi params)
;;  data is stdin supplied data (u8vector)
;;  return values:
;;    body is data (string or u8vector) or an iterable that produces
;;    a stream of data
(def (start-rack-fastcgi-server! address handler)
  (start-fastcgi-server! address (cut rack-fastcgi-respond <> handler)))

(def (rack-fastcgi-respond req handler)
  (def (collect-data body)
    (let (out (open-output-u8vector))
      (for (next body)
        (cond
         ((u8vector? next)
          (write-subu8vector next 0 (u8vector-length next) out))
         ((string? next)
          (write-substring next 0 (string-length next) out))
         (else
          (raise-io-error 'rack-fastcgi-respond "bad response chunk" next))))
      (get-output-u8vector out)))
  
  (try
   (let* (((values status headers body)
           (handler (fastcgi-request-params req)
                    (fastcgi-request-stdin req)))
          (status-text (hash-ref *http-response-codes* status "(Unknown)"))
          (body-data (cond
                      ((u8vector? body) body)
                      ((string? body) (string->bytes body))
                      (else (collect-data body))))
          (hout (open-output-u8vector)))
     (fprintf hout "Status: ~a ~a\r\n" status status-text)
     (for (pair headers)
       (with ([key . value] pair)
         (fprintf hout "~a: ~a\r\n" key value)))
     (fprintf hout "Content-Length: ~a\r\n" (u8vector-length body-data))
     (fprintf hout "\r\n")
     (fastcgi-write-stdout req (get-output-u8vector hout))
     (fastcgi-write-stdout req body-data))
   (catch (e)
     (display "rack response error " (current-error-port))
     (display-exception e (current-error-port))
     (let (errstr (call-with-output-string [] (cut display-exception e <>)))
       (fastcgi-write-stderr req errstr)))))

(def *http-response-codes*
  (hash-eq (100 "Continue")
           (101 "Switching Protocols")
           (200 "OK")
           (201 "Created")
           (202 "Accepted")
           (203 "Non-Authoritative Information")
           (204 "No Content")
           (205 "Reset Content")
           (206 "Partial Content")
           (300 "Multiple Choices")
           (301 "Moved Permanently")
           (302 "Found")
           (303 "See Other")
           (304 "Not Modified")
           (305 "Use Proxy")
           (307 "Temporary Redirect")
           (400 "Bad Request")
           (401 "Unauthorized")
           (402 "Payment Required")
           (403 "Forbidden")
           (404 "Not Found")
           (405 "Method Not Allowed")
           (406 "Not Acceptable")
           (407 "Proxy Authentication Required")
           (408 "Request Timeout")
           (409 "Conflict")
           (410 "Gone")
           (411 "Length Required")
           (412 "Precondition Failed")
           (413 "Request Entity Too Large")
           (414 "Request-URI Too Long")
           (415 "Unsupported Media Type")
           (416 "Requested Range Not Satisfiable")
           (417 "Expectation Failed")
           (500 "Internal Server Error")
           (501 "Not Implemented")
           (502 "Bad Gateway")
           (503 "Service Unavailable")
           (504 "Gateway Timeout")
           (505 "HTTP Version Not Supported")
           ))