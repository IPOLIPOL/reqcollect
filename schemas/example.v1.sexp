(schema
 (id example)
 (name "Requirements sheet")
 (version 0.1.0)

 ;; ---- header fields: filled once, copied into every requirement ----
 (header-field (id author)      (name "Author")      (placeholder "name@example.com") (required true))
 (header-field (id system-name) (name "System name") (placeholder "Main crane")        (required true))
 (header-field (id rds)         (name "RDS")         (placeholder "")                 (required false))
 (header-field (id rds-pp)      (name "RDS-PP")      (placeholder "")                 (required false))

 ;; ---- body fields ----
 (group (id purpose)       (name "Purpose of the system")    (order 1))
 (group (id functional)    (name "Functional requirements")  (order 2))
 (group (id performance)   (name "Performance requirements") (order 3))
 (group (id regulatory)    (name "Regulatory and standards") (order 4))
 (group (id environmental) (name "Environmental conditions") (order 5))
 (group (id interface)     (name "Interfaces")               (order 6))
 (group (id safety)        (name "Safety")                   (order 7))
 (group (id testing)       (name "Testing and verification") (order 8))
 (group (id manufacturing) (name "Manufacturing")            (order 9))

 (field (id text)   (name "Requirement")      (data-type text)   (required true))
 (field (id source) (name "Source")           (data-type string) (required false))
 (field (id note)   (name "Note / rationale") (data-type text)   (required false)))