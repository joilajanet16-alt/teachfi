;; TeachFi Student Performance Contract
;; This contract tracks academic achievements and performance metrics for calculating teacher rewards

;; Constants and Error Codes
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_SCORE (err u400))
(define-constant ERR_STUDENT_NOT_REGISTERED (err u403))
(define-constant ERR_INVALID_COURSE_DATA (err u405))
(define-constant ERR_DUPLICATE_RECORD (err u406))
(define-constant ERR_INVALID_DATE (err u407))
(define-constant ERR_COURSE_NOT_FOUND (err u408))
(define-constant ERR_ACHIEVEMENT_NOT_FOUND (err u409))

;; Performance scoring constants
(define-constant MAX_SCORE u100)
(define-constant MIN_PASSING_SCORE u60)
(define-constant EXCELLENT_THRESHOLD u90)
(define-constant GOOD_THRESHOLD u80)
(define-constant SATISFACTORY_THRESHOLD u70)

;; Achievement point values
(define-constant PERFECT_SCORE_POINTS u10)
(define-constant IMPROVEMENT_POINTS u5)
(define-constant COMPLETION_POINTS u3)
(define-constant PARTICIPATION_POINTS u2)
(define-constant PEER_HELP_POINTS u2)

;; Data Variables
(define-data-var next-student-id uint u1)
(define-data-var next-course-id uint u1)
(define-data-var next-achievement-id uint u1)
(define-data-var total-registered-students uint u0)
(define-data-var current-academic-year uint u2024)
(define-data-var system-active bool true)

;; Student Registration
(define-map students
  { student-id: uint }
  {
    identifier: (string-ascii 30),
    teacher-id: uint,
    grade-level: uint,
    enrollment-date: uint,
    total-courses: uint,
    overall-gpa: uint,
    total-achievements: uint,
    is-active: bool,
    special-needs: bool
  }
)

;; Student identifier lookup
(define-map student-lookup
  { identifier: (string-ascii 30) }
  { student-id: uint }
)

;; Course Information
(define-map courses
  { course-id: uint }
  {
    name: (string-ascii 50),
    subject: (string-ascii 30),
    teacher-id: uint,
    semester: uint,
    academic-year: uint,
    total-students: uint,
    average-score: uint,
    completion-rate: uint,
    is-active: bool
  }
)

;; Student Course Enrollment
(define-map student-courses
  { student-id: uint, course-id: uint }
  {
    enrollment-date: uint,
    current-score: uint,
    assignment-scores: (list 10 uint),
    attendance-rate: uint,
    participation-score: uint,
    final-grade: uint,
    completed: bool,
    dropped-out: bool
  }
)

;; Academic Achievements
(define-map achievements
  { achievement-id: uint }
  {
    student-id: uint,
    teacher-id: uint,
    course-id: uint,
    achievement-type: (string-ascii 30),
    description: (string-ascii 100),
    points-earned: uint,
    date-earned: uint,
    verified: bool
  }
)

;; Performance Analytics
(define-map student-analytics
  { student-id: uint, semester: uint }
  {
    courses-enrolled: uint,
    courses-completed: uint,
    average-score: uint,
    improvement-rate: int,
    attendance-average: uint,
    achievement-points: uint,
    ranking-percentile: uint
  }
)

;; Teacher Performance Summary
(define-map teacher-performance
  { teacher-id: uint, semester: uint }
  {
    total-students: uint,
    average-class-score: uint,
    student-improvement: uint,
    completion-rate: uint,
    satisfaction-rating: uint,
    achievement-count: uint,
    performance-score: uint
  }
)

;; Assignment Tracking
(define-map assignments
  { assignment-id: uint }
  {
    course-id: uint,
    name: (string-ascii 50),
    max-points: uint,
    due-date: uint,
    submission-count: uint,
    average-score: uint,
    is-graded: bool
  }
)

;; Read-only functions for data retrieval
(define-read-only (get-student-info (student-id uint))
  (map-get? students { student-id: student-id })
)

(define-read-only (get-student-by-identifier (identifier (string-ascii 30)))
  (match (map-get? student-lookup { identifier: identifier })
    lookup-result (map-get? students { student-id: (get student-id lookup-result) })
    none
  )
)

(define-read-only (get-course-info (course-id uint))
  (map-get? courses { course-id: course-id })
)

(define-read-only (get-student-course-record (student-id uint) (course-id uint))
  (map-get? student-courses { student-id: student-id, course-id: course-id })
)

(define-read-only (get-achievement-info (achievement-id uint))
  (map-get? achievements { achievement-id: achievement-id })
)

(define-read-only (get-student-analytics (student-id uint) (semester uint))
  (map-get? student-analytics { student-id: student-id, semester: semester })
)

(define-read-only (get-teacher-performance-summary (teacher-id uint) (semester uint))
  (map-get? teacher-performance { teacher-id: teacher-id, semester: semester })
)

(define-read-only (get-system-stats)
  {
    total-students: (var-get total-registered-students),
    next-student-id: (var-get next-student-id),
    next-course-id: (var-get next-course-id),
    current-year: (var-get current-academic-year),
    system-active: (var-get system-active)
  }
)

(define-read-only (calculate-grade-letter (score uint))
  (if (>= score u90)
    "A"
    (if (>= score u80)
      "B"
      (if (>= score u70)
        "C"
        (if (>= score u60)
          "D"
          "F"))))
)

(define-read-only (calculate-gpa-points (score uint))
  (if (>= score u90)
    u400  ;; 4.0 * 100
    (if (>= score u80)
      u300  ;; 3.0 * 100
      (if (>= score u70)
        u200  ;; 2.0 * 100
        (if (>= score u60)
          u100  ;; 1.0 * 100
          u0))))
)

;; Administrative functions
(define-public (toggle-system-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (var-set system-active (not (var-get system-active))))
  )
)

(define-public (advance-academic-year)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set current-academic-year (+ (var-get current-academic-year) u1))
    (ok (var-get current-academic-year))
  )
)

;; Student registration
(define-public (register-student
    (identifier (string-ascii 30))
    (teacher-id uint)
    (grade-level uint))
  (let (
    (student-id (var-get next-student-id))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? student-lookup { identifier: identifier })) ERR_DUPLICATE_RECORD)
    (asserts! (> (len identifier) u0) ERR_INVALID_COURSE_DATA)
    (asserts! (and (>= grade-level u1) (<= grade-level u12)) ERR_INVALID_COURSE_DATA)
    
    ;; Register student
    (map-set students
      { student-id: student-id }
      {
        identifier: identifier,
        teacher-id: teacher-id,
        grade-level: grade-level,
        enrollment-date: stacks-block-height,
        total-courses: u0,
        overall-gpa: u0,
        total-achievements: u0,
        is-active: true,
        special-needs: false
      })
    
    ;; Create identifier lookup
    (map-set student-lookup
      { identifier: identifier }
      { student-id: student-id })
    
    ;; Update contract state
    (var-set next-student-id (+ student-id u1))
    (var-set total-registered-students (+ (var-get total-registered-students) u1))
    
    (ok student-id)
  )
)

;; Create a new course
(define-public (create-course
    (name (string-ascii 50))
    (subject (string-ascii 30))
    (teacher-id uint)
    (semester uint))
  (let (
    (course-id (var-get next-course-id))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_COURSE_DATA)
    (asserts! (> (len subject) u0) ERR_INVALID_COURSE_DATA)
    (asserts! (and (>= semester u1) (<= semester u2)) ERR_INVALID_COURSE_DATA)
    
    ;; Create course
    (map-set courses
      { course-id: course-id }
      {
        name: name,
        subject: subject,
        teacher-id: teacher-id,
        semester: semester,
        academic-year: (var-get current-academic-year),
        total-students: u0,
        average-score: u0,
        completion-rate: u0,
        is-active: true
      })
    
    ;; Update contract state
    (var-set next-course-id (+ course-id u1))
    
    (ok course-id)
  )
)

;; Enroll student in course
(define-public (enroll-student-in-course (student-id uint) (course-id uint))
  (let (
    (student-info (unwrap! (map-get? students { student-id: student-id }) ERR_STUDENT_NOT_REGISTERED))
    (course-info (unwrap! (map-get? courses { course-id: course-id }) ERR_COURSE_NOT_FOUND))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (get is-active student-info) ERR_STUDENT_NOT_REGISTERED)
    (asserts! (get is-active course-info) ERR_COURSE_NOT_FOUND)
    (asserts! (is-none (map-get? student-courses { student-id: student-id, course-id: course-id })) ERR_DUPLICATE_RECORD)
    
    ;; Enroll student in course
    (map-set student-courses
      { student-id: student-id, course-id: course-id }
      {
        enrollment-date: stacks-block-height,
        current-score: u0,
        assignment-scores: (list),
        attendance-rate: u0,
        participation-score: u0,
        final-grade: u0,
        completed: false,
        dropped-out: false
      })
    
    ;; Update course student count
    (map-set courses
      { course-id: course-id }
      (merge course-info { total-students: (+ (get total-students course-info) u1) }))
    
    ;; Update student course count
    (map-set students
      { student-id: student-id }
      (merge student-info { total-courses: (+ (get total-courses student-info) u1) }))
    
    (ok true)
  )
)

;; Record assignment score
(define-public (record-assignment-score
    (student-id uint)
    (course-id uint)
    (score uint))
  (let (
    (course-record (unwrap! (map-get? student-courses { student-id: student-id, course-id: course-id }) ERR_NOT_FOUND))
    (current-scores (get assignment-scores course-record))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (<= score MAX_SCORE) ERR_INVALID_SCORE)
    (asserts! (not (get completed course-record)) ERR_INVALID_COURSE_DATA)
    
    ;; Add new score to list
    (let (
      (updated-scores (unwrap-panic (as-max-len? (append current-scores score) u10)))
      (new-average (calculate-average-score updated-scores))
    )
      ;; Update course record
      (map-set student-courses
        { student-id: student-id, course-id: course-id }
        (merge course-record {
          assignment-scores: updated-scores,
          current-score: new-average
        }))
      
      (ok new-average)
    )
  )
)

;; Record achievement
(define-public (record-achievement
    (student-id uint)
    (teacher-id uint)
    (course-id uint)
    (achievement-type (string-ascii 30))
    (description (string-ascii 100))
    (points-earned uint))
  (let (
    (achievement-id (var-get next-achievement-id))
    (student-info (unwrap! (map-get? students { student-id: student-id }) ERR_STUDENT_NOT_REGISTERED))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (> (len achievement-type) u0) ERR_INVALID_COURSE_DATA)
    (asserts! (> points-earned u0) ERR_INVALID_SCORE)
    
    ;; Record achievement
    (map-set achievements
      { achievement-id: achievement-id }
      {
        student-id: student-id,
        teacher-id: teacher-id,
        course-id: course-id,
        achievement-type: achievement-type,
        description: description,
        points-earned: points-earned,
        date-earned: stacks-block-height,
        verified: false
      })
    
    ;; Update student achievements count
    (map-set students
      { student-id: student-id }
      (merge student-info { total-achievements: (+ (get total-achievements student-info) u1) }))
    
    ;; Update contract state
    (var-set next-achievement-id (+ achievement-id u1))
    
    (ok achievement-id)
  )
)

;; Complete course
(define-public (complete-course (student-id uint) (course-id uint) (final-grade uint))
  (let (
    (course-record (unwrap! (map-get? student-courses { student-id: student-id, course-id: course-id }) ERR_NOT_FOUND))
    (student-info (unwrap! (map-get? students { student-id: student-id }) ERR_STUDENT_NOT_REGISTERED))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (<= final-grade MAX_SCORE) ERR_INVALID_SCORE)
    (asserts! (not (get completed course-record)) ERR_DUPLICATE_RECORD)
    
    ;; Mark course as completed
    (map-set student-courses
      { student-id: student-id, course-id: course-id }
      (merge course-record {
        final-grade: final-grade,
        completed: true
      }))
    
    ;; Update student GPA
    (let (
      (gpa-points (calculate-gpa-points final-grade))
      (total-courses (get total-courses student-info))
      (current-gpa (get overall-gpa student-info))
      (new-gpa (if (> total-courses u1)
        (/ (+ (* current-gpa (- total-courses u1)) gpa-points) total-courses)
        gpa-points))
    )
      (map-set students
        { student-id: student-id }
        (merge student-info { overall-gpa: new-gpa }))
    )
    
    (ok final-grade)
  )
)

;; Calculate teacher performance score
(define-public (calculate-teacher-performance (teacher-id uint) (semester uint))
  (begin
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    ;; This would normally aggregate all student data for the teacher
    ;; For simplicity, we'll create a placeholder calculation
    (map-set teacher-performance
      { teacher-id: teacher-id, semester: semester }
      {
        total-students: u25,
        average-class-score: u85,
        student-improvement: u15,
        completion-rate: u95,
        satisfaction-rating: u88,
        achievement-count: u45,
        performance-score: u87
      })
    
    (ok u87) ;; Return calculated performance score
  )
)

;; Helper function to calculate average score from list
(define-private (calculate-average-score (scores (list 10 uint)))
  (let (
    (total (fold + scores u0))
    (count (len scores))
  )
    (if (> count u0)
      (/ total count)
      u0)
  )
)

