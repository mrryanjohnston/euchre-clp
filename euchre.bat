(println (new-uuid))
(println (new-uuid))
(println (new-uuid))
(println (new-uuid))
(defrule user-connected
  (connection ?sid ?id)
  =>
  (println "User " ?sid " connected via Websocket " ?id)
  (format ?id "Hello, client %s! Your connection id is %s" ?sid ?id))

(defrule user-disconnected
  (connection ?sid ?id)
  (disconnection ?id)
  =>
  (println "User " ?sid " disconnected from connection " ?id))

;(defrule echo
(defrule received-message
  ;(received-message-from ?id)
  ?f <- (received-message-from ?id)
  =>
  (retract ?f)
  ;(println "Received message from " ?id ": " (readline ?id)))
  (println "Received message from " ?id)
  (assert (received-message ?id (readline ?id))))

(defrule create-game
  ?f <- (received-message ?id "create-game")
  =>
  (retract ?f)
  (println "Creating game for user " ?id "...")
  (assert (game ?id))
  (format ?id "join %s" ?id))

(defrule list-games
  ?f <- (received-message ?id "list-games")
  =>
  (retract ?f)
  (println "Listing games for user " ?id "...")
  (bind ?out "games")
  (do-for-all-facts ((?g game)) TRUE
    (bind ?out (str-cat ?out " " (nth$ 1 ?g:implied))))
  (printout ?id ?out))
