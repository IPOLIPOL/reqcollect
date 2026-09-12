(submission
 (schema-id crane)
 (schema-version 0.1.0)
 (created-at "2026-01-15T09:14:22Z")
 (author "alice@example.com")
 (requirements
  (requirement
   (group performance)
   (text "The crane must lift the transformer, mass 8 t.")
   (source "Contract-2026-014")
   (note ""))
  (requirement
   (group performance)
   (text "Load-capacity safety factor >= 1.25.")
   (source "Internal-STD-07")
   (note "Bound to feature LoadCapacity"))
  (requirement
   (group regulatory)
   (text "Certification per EN for Europe.")
   (source Regulation)
   (note ""))))