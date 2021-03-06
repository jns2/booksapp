(ql:quickload '(cl-who hunchentoot parenscript elephant))

(defpackage :fav-books
  (:use :cl :cl-who :hunchentoot :parenscript :elephant)) 

(in-package :fav-books)

(defmethod add-quote (book user-quote)
  (push user-quote (quotelst book)))

;;Pseudo-backend below

(defun book-from-name (name)
  (get-instance-by-value 'persistent-book 'name name))

(defun book-exists? (name)
  (book-from-name name))

(defun add-book (name)
  (with-transaction ()
    (unless (book-exists? name)
      (make-instance 'persistent-book :name name))))

(defun books ()
  (sort (get-instances-by-class 'persistent-book) #'string-lessp :key #'name))

;;View functions start below.

(defmacro standard-page ((&key title) &body body)
  `(with-html-output-to-string (*standard-output* nil :prologue t :indent t)
     (:html
      (:head 
       (:meta :content "text/html"
	      :charset "utf-8")
       (:title ,title)
       (:link :href "/retro.css"
	      :media "screen"
	      :rel "stylesheet"
              :type "text/css"))    
      (:body 
       ,@body))))

;;Now we get into the web server-related stuff.

(setf *web-server* (hunchentoot:start (make-instance 'hunchentoot:easy-acceptor :port 8080)))

;(push (create-prefix-dispatcher "/bookshome" 'bookshome) *dispatch-table*)

(defmacro define-url-fn ((name) &body body)
  `(progn
     (defun ,name ()
       ,@body)
     (push (create-prefix-dispatcher 
	    ,(format nil "/~(~a~)" name) ',name) *dispatch-table*)))

(define-url-fn (home)
  (standard-page (:title "Books")
    (:h1 "My Favorite Books")
    (:p "Read a good book lately? Add it " (:a :href "new-book" "here."))
    (:h2 "All books")
    (dolist (book(books))
      (htm
       (:p
	(:a :href (format nil "delete-book?name=~a" (name book)) "X")
	(fmt "~A" (name book))
	(:a :href (format nil "quotations?name=~a" (name book)) "Quotes"))))))

(define-url-fn (new-book)
  (standard-page (:title "Add a new book")
    (:h1 "Add a new book")
    (:form :action "/book-added" :method "post" 
	   (:p "What is the name of the book?" (:br)
	       (:input :type "text"  
		       :name "name" 
		       :class "txt"))
	   (:p (:input :type "submit" 
		       :value "Add" 
		       :class "btn")))
    (:a :href "home" "< Home")))

(define-url-fn (book-added)
  (let ((name (parameter "name")))
    (unless (or (null name) (zerop (length name)))
      (add-book name))
    (redirect "/home")))

(define-url-fn (quotations)
  (let ((name (parameter "name")))
    (if name
	(standard-page (:title "Quotes")
	  (:h1 (fmt "Quotes from ~a" name))
	  (dolist (quotation (quotelst (book-from-name name)))
	    (htm
	     (:p (fmt "~a" quotation))))
	  (:form :action (format nil "/quote-added?book=~a" name) :method "post"
		 (:p "Enter new quotation below." (:br)
		     (:input :type "text"
			     :name "newquote"
			     :class "txt"))
		 (:p (:input :type "submit"
			     :value "Add"
			     :class "btn"))
	  (:a :href "home" "< Home"))))))

(define-url-fn (quote-added)
    (let ((newquote (parameter "newquote")))
      (unless (or (null newquote) (zerop (length newquote)))
	(add-quote (book-from-name (parameter "book")) newquote))
      (redirect (format nil "/quotations?name=~a" (parameter "book")))))

(define-url-fn (delete-book)
  (let ((name (parameter "name")))
    (if name
	(drop-instance (book-from-name name)))
    (redirect "/home")))

;;Database stuff.

(setf *store* (open-store '(:clsql (:postgresql "localhost" "bookdb" "postgres" "books"))))

(defpclass persistent-book ()
  ((name :reader name
	 :initarg :name
	 :index t)
   (quotes :initform '()
	   :accessor quotelst
	   :index t)))