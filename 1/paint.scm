(load "./cairolib.scm")
(load "./cairo-wrapper.scm")
(load "./parser.scm")
(use srfi-27)
(define repaint? #f)
(define-method paint (c (f <frame>))
  (paint-content c f)
  (for-each (cut paint c <>) (~ f 'kids)))

(define-method set-source-color ((cr (ptr <cairo_t>)) vec)
  (if (eq? 3 (vector-length vec))
    (set-source-rgb  cr (~ vec 0) (~ vec 1) (~ vec 2))
    (set-source-rgba cr (~ vec 0) (~ vec 1) (~ vec 2) (~ vec 3))))

(define-method paint-content (c (f <frame>))
  (define cr (~ c 'cairo))
  (define x  (~ f 'pos 0))
  (define y  (~ f 'pos 1))
  (define move-cairo (lambda () (cairo_move_to cr x y)))

  ; background
  (when (not (eq? (~ f 'style :background-color) 'transparent))
    (set-source-color cr (~ f 'style :background-color))
    (case (~ f 'style :shape)
      ((round) (cairo_arc cr (+ (~ f 'pos 0) (* 0.5 (~ f 'size 0)))
                             (+ (~ f 'pos 1) (* 0.5 (~ f 'size 1)))
                             (* 0.5 (~ f 'size 0))
                             0 
                             (* 8 (atan 1))))
    (else (cairo_rectangle cr (~ f 'pos 0) (~ f 'pos 1) (~ f 'size 0) (~ f 'size 1))))
    (cairo_fill cr))
  ; background-image
  (when (not (eq? (~ f 'style :background-image) 'none))
    (let1 png (get-png (~ f 'style :background-image))
      (cairo_set_source_surface cr png 0 0)
      (cairo_rectangle  cr (~ f 'pos 0) (~ f 'pos 1) (~ f 'size 0) (~ f 'size 1))
      (cairo_fill cr)))
  ; border
  (move-cairo)
  (when (not (eq? (~ f 'style :border-style-left) 'none))
    (set-source-color cr (~ f 'style :border-color-left))
    (cairo_rel_line_to cr 0 (~ f 'size 1))
    (cairo_stroke cr))

  (move-cairo)
  (cairo_move_to cr (~ f 'pos 0) (~ f 'pos 1))
  (cairo_rel_move_to cr 0 (~ f 'size 1))
  (when (not (eq? (~ f 'style :border-style-bottom) 'none))
    (set-source-color cr  (~ f 'style :border-color-bottom))
    (cairo_rel_line_to cr (~ f 'size 0) 0)
    (cairo_stroke cr))

  (move-cairo)
  (cairo_rel_move_to cr (~ f 'size 0) (~ f 'size 1))
  (when (not (eq? (~ f 'style :border-style-right) 'none))
      (set-source-color cr (~ f 'style :border-color-right))
      (cairo_rel_line_to cr 0 (- (~ f 'size 1)))
      (cairo_stroke cr))

  (move-cairo)
  (cairo_rel_move_to cr (~ f 'size 0) 0)
  (when (not (eq? (~ f 'style :border-style-top) 'none))
    (set-source-color cr (~ f 'style :border-color-top))
    (cairo_rel_line_to cr (- (~ f 'size 0)) 0)
    (cairo_stroke cr))

  ; text
  (when (is-a? f <text-frame>)
    (set-source-rgb cr (~ f 'style :color 0) (~ f 'style :color 1) (~ f 'style :color 2))
    (select-font-face cr (~ f 'style :font-face) (slant (~ f 'style :font-slant)) (weight (~ f 'style :font-weight)))
    (set-font-size    cr (~ f 'style :font-size))
    (move-to          cr (~ f 'pos 0) (+ (~ f 'pos 1) (~ f 'style :font-size)))
    (show-text        cr (or (~ f 'text) ""))))

(define (norm len scale accessor)
  (case (car len)
    ((rel) (* (cadr len) (accessor (~ scale 'mater))))
    (else (car len))))

(define (? . a)
  (if (null? (cddr a))
    (%? (car a) (cadr a))
    (and (%? (car a) (cadr a))
         (apply (pa$ ? (ref (car a) (cadr a))) (cddr a)))))

(define-method %? ((hash <hash-table>) key)
  (hash-table-exists? hash key))
(define-method %? (obj slot) #t)

(define-method flow-horizontal ((f <frame>) c)
  (set! (~ f 'pos) (vector-copy (~ c 'pos)))
  (for-each (^k
      (rel-move-to c (~ f 'size 0) 0)
      (flow k c))
    (~ f 'kids)))

(define-method flow-vertical ((f <frame>) c)
  (set! (~ f 'pos) (vector-copy (~ c 'pos)))
  (for-each (^k
      (rel-move-to c 0 (~ f 'size 1))
      (flow k c))
    (~ f 'kids)))

(define-class <window> ()
  ((frame)
   (size)
   (document)
   (document-by-id)
   (document-uri-internal)
   (document-uri
     :allocation :virtual
     :slot-ref
       (^w (slot-ref w 'document-uri-internal))
     :slot-set!
       (^(w uri)
         (slot-set! w 'document-uri-internal uri)
         (let1 pair (spd-parse (open-input-file (~ window 'document-uri)))
           (set! (~ window 'document-by-id) (cadr pair))
           (set! (~ window 'document) (car pair)))))
   (stylesheet)
   (stylesheet-uri)
   (cairo)
   (cairo-surface)
   (current-page)
   (scroll-position :init-value #(0 0))
   (surface)
   (viewport)))

(define-class <main-window> (<window>)
  ())

(define window #f)
(define (test)
  (set! window (make <main-window> 600 300))
  (set! (~ window 'stylesheet-uri) "test/1.sst.s")
  (set! (~ window 'document-uri)   "test/1.spd.s")
  (set! (~ window 'document) (car (spd-parse (open-input-file (~ window 'document-uri)))))
  (paint window)
  (profiler-reset)
  (profiler-start)
  (mainloop))

(define-method initialize ((w <main-window>) initargs)
  (init (car initargs) (cadr initargs))
  (set! (~ w 'size) (vector (car initargs) (cadr initargs)))
  (set! (~ w 'cairo) cairo)
  (set! (~ w 'surface) sdl-sf))

(define (text-extent cr)
  (define extent (make <cairo_text_extents_t>))
  (define a-extent (make <cairo_text_extents_t>))
  (^(str style)
    (cairo_set_font_size cr (~ style :font-size))
    (select-font-face cr (~ style :font-face) (slant (~ style :font-slant)) (weight (~ style :font-weight)))
    (cairo_text_extents cr "a" (ptr a-extent))
    (cairo_text_extents cr (string-append "a" str "a") (ptr extent))
    (- (~ extent 'width) (* 2 (~ a-extent 'width)))))

(define meter% #f)
(define-method paint ((w <window>))
  (set! meter% (cut meter <> (text-extent (~ w 'cairo))))
  (sst-reset (~ w 'document))
  (sst-apply (~ w 'document) (open-input-file (~ w 'stylesheet-uri)))
  (set!  (~ w 'frame) (spd-frame-construct (~ w 'document)))
  (set!  (~ w 'frame 'style :min-size) (~ w 'size))
  (if (not (eq? (~ w 'frame 'style :scroll) 'horizontal))
    (set!  (~ w 'frame 'style :max-size 0) (~ w 'size 0)))
  (if (not (eq? (~ w 'frame 'style :scroll) 'vertical))
    (set!  (~ w 'frame 'style :max-size 1) (~ w 'size 1)))
  (meter (~ w 'frame) (text-extent (~ w 'cairo)))
  (set!  (~ w 'frame 'pos) (vector 0 0))
  (flow  (~ w 'frame))
  ;(dump-tree (~ w 'document))
  ;(dump-tree (~ w 'frame))
  (set! (~ w 'current-page 'size) (~ w 'frame 'size))
  (set! (~ w 'current-page 'cairo-surface) (cairo_image_surface_create CAIRO_FORMAT_ARGB32 (~ w 'current-page 'size 0) (~ w 'current-page 'size 1)))
  (set! (~ w 'current-page 'cairo) (cairo_create (~ w 'current-page 'cairo-surface)))
  (paint (~ w 'current-page) (~ w 'frame))
  (cairo_set_source_surface (~ w 'cairo) (~ w 'current-page 'cairo-surface) (- (~ w 'current-page 'scroll-position 0)) (- (~ w 'current-page 'scroll-position 1)))
  (cairo_paint (~ w 'cairo))
  (SDL_Flip (~ w 'surface)))

(define-method repaint ((w <main-window>))
  (cairo_set_source_surface (~ w 'cairo) (~ w 'current-page 'cairo-surface) (- (~ w 'current-page 'scroll-position 0)) (- (~ w 'current-page 'scroll-position 1)))
  (cairo_paint (~ w 'cairo))
  (SDL_Flip (~ w 'surface)))

(define cache (make-hash-table 'equal?))
(define (get-png file)
  (when (not (hash-table-exists? cache file)) (set! (~ cache file) (cairo_image_surface_create_from_png file)))
  (~ cache file))
 
(define (weight value)
  (case value
    ((500 600 700 800 900 bold) CAIRO_FONT_WEIGHT_BOLD)
    ((100 200 300 400 normal) CAIRO_FONT_WEIGHT_NORMAL)))

(define (slant value)
  (case value
    ((italic)  CAIRO_FONT_SLANT_ITALIC)
    ((oblique) CAIRO_FONT_SLANT_OBLIQUE)
    ((normal)  CAIRO_FONT_SLANT_NORMAL)))