(ql:quickload '(cl-who hunchentoot parenscript))

(defpackage :fav-books
  (:use :cl :cl-who :hunchentoot :parenscript))

(in-package :fav-books)

(defclass book ()
  ((name :reader name
	 :initarg :name)
   (quotes :initform '()
	   :accessor quotes)))

(defmethod add-quote (book user-quote)
  (push user-quote (quotes book)))

;;Pseudo-backend below

(defvar *books* '())

(defun book-from-name (name)
  (find name *books* 
	:test #'string-equal
	:key #'name))

(defun book-exists? (name)
  (book-from-name name))

(defun add-book (name)
  (unless (book-exists? name)
    (push (make-instance 'book :name name) *books*)))

(defun books ()
  (sort (copy-list *books*) #'string-lessp :key #'name))

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

(defun bookshome ()
  (standard-page (:title "Favorite Books")
    (:h1 "Arjan's Favorite Books")
    (:p "I'll finish this later...")))

;;Now we get into the web server-related stuff.

;(hunchentoot:start (make-instance 'hunchentoot:easy-acceptor :port 8080))

;(push (create-prefix-dispatcher "/bookshome.htm" 'bookshome) *dispatch-table*)

(defmacro define-url-fn ((name) &body body)
  `(progn
     (defun ,name ()
       ,@body)
     (push (create-prefix-dispatcher 
	    ,(format nil "/~(~a~).htm" name) ',name) *dispatch-table*)))

(define-url-fn (home)
  (standard-page (:title "Books")
    (:h1 "My Favorite Books")
    (:p "Read a good book lately? Add it " (:a :href "new-book.htm" "here."))
    (:h2 "All books")
    (:div :id "chart"
	  (:ul
	   (dolist (book(books))
	     (htm
	      (:li
	       (fmt "~A" (name book))
	       (:a :href (format nil "quotations.htm?name=~a" (name book)) "Quotes"))))))))

(define-url-fn (new-book)
  (standard-page (:title "Add a new book")
    (:h1 "Add a new book")
    (:form :action "/book-added.htm" :method "post" 
	   (:p "What is the name of the book?" (:br)
	       (:input :type "text"  
		       :name "name" 
		       :class "txt"))
	   (:p (:input :type "submit" 
		       :value "Add" 
		       :class "btn")))))

(define-url-fn (book-added)
  (let ((name (parameter "name")))
    (unless (or (null name) (zerop (length name)))
      (add-book name))
    (redirect "/home.htm")))

(define-url-fn (quotations)
  (let ((bk (book-from-name (parameter "name"))))
    (if bk
	(standard-page (:title "Quotes")
	  (:h1 (format nil "Quotes from ~a" (name bk)))
	  (:p "Quotations to come later...")
	  (:p (format nil "~a" (name bk)))))))