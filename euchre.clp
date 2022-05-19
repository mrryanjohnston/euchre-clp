(deftemplate card-in-hand
	(slot game)
	(slot seat)
	(slot name)
	(slot suit)
	(slot choice (default 0)))
(deftemplate card-in-play
	(slot game)
	(slot seat)
	(slot name)
	(slot suit)
	(slot choice (default 0)))
(deftemplate game
	(slot id))
(deftemplate spectator
	(slot game)
	(slot sid))
(deftemplate player
	(slot game)
	(slot seat)
	(slot sid))
(deftemplate connection
	(slot sid)
	(slot wsid))
(deftemplate game-connection
	(slot game)
	(slot wsid))

(deffunction broadcast (?gid ?str)
	(do-for-all-facts ((?f game-connection)) (eq ?f:game ?gid)
	  (printout ?f:wsid ?str)))

(deffunction broadcast-to-other-players (?gid ?seat ?str)
	(do-for-all-facts ((?p player) (?c connection) (?g game-connection)) (and (eq ?c:wsid ?g:wsid) (eq ?c:sid ?p:sid) (eq ?p:game ?gid) (eq ?g:game ?gid) (<> ?p:seat ?seat))
	  (printout ?g:wsid ?str)))

(deffunction send-directly-to-player (?gid ?seat ?str)
	(do-for-all-facts ((?p player) (?c connection) (?g game-connection)) (and (eq ?c:wsid ?g:wsid) (eq ?c:sid ?p:sid) (eq ?p:game ?gid) (eq ?g:game ?gid) (= ?p:seat ?seat))
	  (printout ?g:wsid ?str)))

(deffacts debug
	(game (id (new-uuid)))
	(game (id (new-uuid))))
(defrule start => (println "[euchre.clp] Hello from euchre.clp!"))

(defrule new-user
	(connection (sid ?sid))
	(not (session ?sid))
	=>
	(println "[euchre.clp] New User " ?sid " connected for the first time!")
	(assert (session ?sid)))

(defrule connection
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	=>
	(println "[euchre.clp] User " ?sid " connected on websocket " ?wsid)
	(printout ?wsid "say SERVER Welcome to the game!"))

(defrule disconnection
	(session ?sid)
	?c <- (connection (sid ?sid) (wsid ?wsid))
	?d <- (disconnection ?wsid)
	=>
	(retract ?c ?d)
	(do-for-all-facts ((?g game-connection)) (eq ?g:wsid ?wsid)
	  (retract ?g))
	(println "[euchre.clp] User " ?sid " disconnected from websocket " ?wsid))

(defrule read-message-from-buffer
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	?m <- (received-message-from ?wsid)
	=>
	(println "[euchre.clp] Reading message from websocket " ?wsid)
	(assert (message-from ?wsid (readline ?wsid)))
	(retract ?m))

(defrule explode-message-from-websocket
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	?m <- (message-from ?wsid ?msg)
	=>
	(println "[euchre.clp] Message from websocket " ?wsid ": " ?msg)
	(assert (parsed-message-from ?wsid (explode$ ?msg)))
	(retract ?m))

(defrule illegal-say
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(not (game-connection (wsid ?wsid)))
	?s <- (parsed-message-from ?wsid say $?msg)
	=>
	(retract ?s))

(defrule broadcast-say
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	?s <- (parsed-message-from ?wsid say $?msg)
	=>
	(broadcast ?gid (format nil "say %s %s" ?sid (implode$ ?msg))) 
	(retract ?s))

(defrule list-games
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	?s <- (parsed-message-from ?wsid gameslist)
	(not (game-connection (wsid ?wsid)))
	=>
	(do-for-all-facts ((?f game)) TRUE
	  (format ?wsid "gameslist %s" ?f:id))
	(retract ?s))

(defrule illegal-while-in-game
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	?s <- (parsed-message-from ?wsid join $?)
	=>
	(retract ?s))

(defrule create-game
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	?s <- (parsed-message-from ?wsid create)
	=>
	(bind ?gid (new-uuid))
	(format ?wsid "join %s" ?gid)
	(assert (game (id ?gid))
		(spectator (game ?gid) (sid ?sid))
		(game-connection (game ?gid) (wsid ?wsid)))
	(retract ?s))

(defrule join-game
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	?s <- (parsed-message-from ?wsid join ?gid)
	(not (game-connection (game ?gid) (wsid ?wsid)))
	=>
	(assert (game-connection (game ?gid) (wsid ?wsid)))
	(format ?wsid "join %s" ?gid)
	(retract ?s))

(defrule spectate
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	(not (spectator (game ?gid) (sid ?sid)))
	(not (player (game ?gid) (sid ?sid)))
	=>
	(broadcast ?gid (format nil "say Player %s starts spectating" ?sid))
	(assert (spectator (game ?gid) (sid ?sid))))

(defrule leave-game
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	?g <- (game-connection (game ?gid) (wsid ?wsid))
	?s <- (parsed-message-from ?wsid leave)
	=>
	(retract ?g ?s))

(defrule leave-spectator
	(session ?sid)
	(game (id ?gid))
	?s <- (spectator (game ?gid) (sid ?sid))
	(forall (connection (sid ?sid) (wsid ?w))
		(not (game-connection (game ?gid) (wsid ?w))))
	=>
	(broadcast ?gid (format nil "say Player %s stops spectating" ?sid))
	(retract ?s))

(defrule game-does-not-exist
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	?s <- (parsed-message-from ?wsid join ?gid)
	(not (game (id ?gid)))
	=>
	(printout ?wsid "error ERROR: Could not join game because it does not exist")
	(retract ?s))

(defrule sit
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	?sp <- (spectator (game ?gid) (sid ?sid))
	?p <- (parsed-message-from ?wsid sit ?seat&1|2|3|4)
	(not (player (game ?gid) (seat ?seat)))
	=>
	(assert (player (game ?gid) (seat ?seat) (sid ?sid)))
	(retract ?sp ?p))

(defrule announce-player-sits-down
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	=>
	(broadcast ?gid (format nil "say Player %s sits at seat %d" ?sid ?seat)))

(defrule inform-player-sits-down
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	=>
	(format ?wsid "sit %d" ?seat))

(defrule seat-taken
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(spectator (game ?gid) (sid ?sid))
	?p <- (parsed-message-from ?wsid sit ?seat)
	(player (game ?gid) (seat ?seat) (sid ~?sid))
	=>
	(printout ?wsid "error ERROR: Could not sit there; seat is taken")
	(retract ?p))

(defrule already-sitting
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid))
	?p <- (parsed-message-from ?wsid sit ?seat)
	(game-connection (game ?gid) (wsid ?wsid))
	=>
	(printout ?wsid "error ERROR: Could not sit there; you're already sitting down")
	(retract ?p))

(defrule stand
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	?pl <- (player (game ?gid) (seat ?seat) (sid ?sid))
	?p <- (parsed-message-from ?wsid stand)
	=>
	(printout ?wsid "stand")
	(retract ?pl ?p)
	(assert (spectator (game ?gid) (sid ?sid)))
	(broadcast ?gid (format nil "say Player %s stands up" ?sid)))

(defrule already-standing
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(spectator (game ?gid) (sid ?sid))
	?p <- (parsed-message-from ?wsid stand)
	(game-connection (game ?gid) (wsid ?wsid))
	=>
	(printout ?wsid "error ERROR: Could not stand; you're not sitting down")
	(retract ?p))

(deffacts datum
	(suit hearts)
	(suit diamonds)
	(suit clubs)
	(suit spades)
	(opposite-suit clubs spades)
	(opposite-suit spades clubs)
	(opposite-suit hearts diamonds)
	(opposite-suit diamonds hearts)
	(player-to-the-left-of 1 2)
	(player-to-the-left-of 2 3)
	(player-to-the-left-of 3 4)
	(player-to-the-left-of 4 1)
	(team-member 1 1)
	(team-member 1 3)
	(team-member 2 2)
	(team-member 2 4)
	(card-value 9 9)
	(card-value 10 10)
	(card-value jack 11)
	(card-value queen 12)
	(card-value king 13)
	(card-value ace 14)
	(card-score 9 9)
	(card-score 10 10)
	(card-score jack 11)
	(card-score queen 12)
	(card-score king 13)
	(card-score ace 14))

(defrule setup
	(game (id ?id))
	(player (game ?id) (seat 1))
	(player (game ?id) (seat 2))
	(player (game ?id) (seat 3))
	(player (game ?id) (seat 4))
	=>
	(assert
	(hand ?id 1)
	(hand ?id 2)
	(hand ?id 3)
	(hand ?id 4)
	(team-score ?id 1 0)
	(team-score ?id 2 0)
	(team-tricks-taken ?id 1 0)
	(team-tricks-taken ?id 2 0)
	(dealer ?id 1)
	(dealt-round ?id 0)
	(shuffled-deck ?id)
	(unshuffled-deck ?id
	 9 spades
	 10 spades
	 jack spades
	 queen spades
	 king spades
	 ace spades
	 9 hearts
	 10 hearts
	 jack hearts
	 queen hearts
	 king hearts
	 ace hearts
	 9 diamonds
	 10 diamonds
	 jack diamonds
	 queen diamonds
	 king diamonds
	 ace diamonds
	 9 clubs
	 10 clubs
	 jack clubs
	 queen clubs
	 king clubs
	 ace clubs)))

(defrule start-dealing
        (player-to-the-left-of ?d ?p)
	(game (id ?gid))
	(dealer ?gid ?d)
	?u <- (unshuffled-deck ?gid $?cards&:(= (length$ ?cards) 48))
	?s <- (shuffled-deck ?gid)
	=>
	(retract ?s ?u)
	(bind ?ii (* (random 1 24) 2))
	(bind ?i (- ?ii 1))
	(assert
		(card-in-hand (game ?gid) (seat ?p) (name (nth$ ?i ?cards)) (suit (nth$ ?ii ?cards)))
		(shuffled-deck ?gid (nth$ ?i ?cards) (nth$ ?ii ?cards))
		(last-dealt ?gid ?p)
		(unshuffled-deck ?gid (delete$ ?cards ?i ?ii))))

(defrule continue-dealing
	(game (id ?gid))
	(player-to-the-left-of ?p ?np)
	?l <- (last-dealt ?gid ?p)
	?u <- (unshuffled-deck ?gid $?cards&:(and (<= (length$ ?cards) 46) (> (length$ ?cards) 8)))
	?s <- (shuffled-deck ?gid $?scards)
	=>
	(retract ?l ?s ?u)
	(bind ?ii (* (random 1 (integer (/ (length$ ?cards) 2))) 2))
	(bind ?i (- ?ii 1))
	(assert
		(card-in-hand (game ?gid) (seat ?np) (name (nth$ ?i ?cards)) (suit (nth$ ?ii ?cards)))
		(shuffled-deck ?gid $?scards (nth$ ?i ?cards) (nth$ ?ii ?cards))
		(last-dealt ?gid ?np)
		(unshuffled-deck ?gid (delete$ ?cards ?i ?ii))))

(defrule announce-card-in-hand
	(game (id ?gid))
	(card-in-hand (game ?gid) (seat ?s) (name ?name) (suit ?suit))
	=>
	(broadcast-to-other-players ?gid ?s (format nil "cardinhand %d" ?s))
	(send-directly-to-player ?gid ?s (format nil "cardinhand %d %s %s" ?s (sym-cat ?name) ?suit)))

(defrule done-dealing
	(game (id ?gid))
	?d <- (dealt-round ?gid ?dealt)
	?l <- (last-dealt ?gid ?)
	(unshuffled-deck ?gid $?cards&:(= (length$ ?cards) 8))
	=>
	(retract ?d ?l)
	(assert
		(kitty ?gid)
		(dealt-round ?gid (+ ?dealt 1))))

(defrule kitty
	(game (id ?gid))
	?u <- (unshuffled-deck ?gid $?cards&:(and (> (length$ ?cards) 0) (<= (length$ ?cards) 8)))
	?k <- (kitty ?gid $?kitty)
	?s <- (shuffled-deck ?gid $?scards)
	=>
	(retract ?k ?s ?u)
	(bind ?ii (* (random 1 (integer (/ (length$ ?cards) 2))) 2))
	(bind ?i (- ?ii 1))
	(assert
		(unshuffled-deck ?gid (delete$ ?cards ?i ?ii))
		(shuffled-deck ?gid $?scards (nth$ ?i ?cards) (nth$ ?ii ?cards))
		(kitty ?gid ?kitty (nth$ ?i ?cards) (nth$ ?ii ?cards))))

(defrule announce-kitty
        (player-to-the-left-of ?d ?p)
	(game (id ?gid))
	(dealer ?gid ?d)
	(unshuffled-deck ?gid)
	?k <- (kitty ?gid $? ?name ?suit)
	=>
	(broadcast ?gid kitty)
	(broadcast ?gid kitty)
	(broadcast ?gid kitty)
	(broadcast ?gid (format nil "kitty %s %s" ?name ?suit)))

(defrule pick-it-up-or-pass
	?b <- (bidder ?id ?p&:(< ?p 5))
	(not (bidder ?id ?p ?))
	=>
	(print "Player " ?p " pick-it-up or pass?: ")
	(assert (bidder ?id ?p (read))))

(defrule illegal-bidder-choice
	?b <- (bidder ?id ? ~pick-it-up&~pass)
	=>
	(println "error ERROR: Please only enter pick-it-up or pass")
	(retract ?b))

(defrule bidder-pass
	(bidder ?id ?b)
	(bidder ?id ?b pass)
	=>
	(assert (bidder ?id (+ ?b 1))))

(defrule all-bidders-pass
	(dealer ?id ?d)
	?p <- (possible-trump-card ?id ?t ?name ?suite)
	(forall (hand ?id ?p $?) (bidder ?id ?p pass))
	=>
	(println "Everyone passed on using " ?suite " as trump")
	(retract ?p)
	(assert (chooses-trump-suite ?id (+ ?d 1))))

(defrule reset-bidder
	?b <- (bidder ?id 5)
	=>
	(retract ?b)
	(assert (bidder ?id 1)))

(defrule reset-chooses-trump-suite
	?c <- (chooses-trump-suite ?id 5)
	=>
	(retract ?c)
	(assert (chooses-trump-suite ?id 1)))

(defrule player-chooses-trump-suite
	(chooses-trump-suite ?id ?c&~5)
	(not (trump-suite ?id ? ?))
	=>
	(println "Player " ?c " chooses trump suite")
	(println "hearts")
	(println "diamonds")
	(println "clubs")
	(println "spades")
	(print "choice: ")
	(assert (trump-suite ?id (read))))

(defrule bad-trump-suite
	?t <- (trump-suite ?id ~hearts&~diamonds&~clubs&~spades)
	=>
	(retract ?t)
	(println "error ERROR: bad trump suite"))

(defrule announce-trump-suite
	(trump-suite ?id ?t&hearts|diamonds|clubs|spades)
	=>
	(println "Trump suite is " ?t))

(defrule clean-up-chooses-trump-suite
	?c <- (chooses-trump-suite ?id ?)
	(trump-suite ?id hearts|diamonds|clubs|spades)
	=>
	(retract ?c))

(defrule trump-card-picked-up
	(dealer ?id ?d)
	(hand ?id ?d $?cards)
	?p <- (possible-trump-card ?id ?name ?suite)
	(bidder ?id ?)
	(bidder ?id ? pick-it-up)
	=>
	(retract ?p)
	(assert
		(trump-card ?id ?name ?suite)
		(trump-suite ?id ?suite)))

(defrule clean-up-bidders
	?b <- (bidder ?id $?)
	(trump-suite ?id hearts|diamonds|clubs|spades)
	=>
	(retract ?b))

(defrule dealer-picks-up-trump-card
	(dealer ?id ?d)
	(hand ?id ?d $?cards)
	(trump-card ?id ?name ?suite)
	(not (swap-choice ?id ?))
	=>
	(println "Choose a card for dealer to swap with " ?name " of " ?suite)
	(loop-for-count (?c 0 4) do
		(bind ?n (+ (* ?c 2) 1))
		(bind ?s (+ ?n 1))
		(println (+ ?c 1) ": " (nth$ ?n ?cards) " of " (nth$ ?s ?cards)))
	(print "choice: ")
	(assert (swap-choice ?id (read))))

(defrule bad-choice
	?l <- (swap-choice ?id FALSE)
	=>
	(retract ?l)
	(println "error ERROR: Please enter a number"))

(defrule choice-out-of-range
	?l <- (swap-choice ?id ~1&~2&~3&~4&~5)
	=>
	(retract ?l)
	(println "error ERROR: Please enter a number between 1 and 5"))

(defrule dealer-chooses
	(dealer ?id ?d)
	?h <- (hand ?id ?d $?cards)
	?k <- (kitty ?id $?rest)
	?t <- (trump-card ?id ?name ?suite)
	?l <- (swap-choice ?id ?i)
	=>
	(retract ?h ?k ?l ?t)
	(bind ?n (+ (* (- ?i 1) 2) 1))
	(bind ?s (+ ?n 1))
	(println "Dealer picks up " ?name " of " ?suite)
	(println "Dealer discards " (nth$ ?n ?cards) " of " (nth$ ?s ?cards) " from hand into kitty")
	(assert
		(kitty ?id ?rest (nth$ ?n ?cards) (nth$ ?s ?cards))
		(hand ?id ?d (delete$ ?cards ?n ?s) ?name ?suite)))

(defrule begin-tricks
	(dealer ?id ?d)
	(trump-suite ?id hearts|diamonds|clubs|spades)
	(not (chooses-trump-suite ?id ?))
	(not (trump-card ?id ? ?))
	=>
	(assert (trick ?id 1 (+ ?d 1))))

(defrule reset-trick
	?t <- (trick ?id ?trick 5)
	=>
	(retract ?t)
	(assert (trick ?id ?trick 1)))

(defrule players-turn
	(dealer ?id ?d)
	(hand ?id ?p $?cards)
	(trick ?id ?trick ?p)
	(not (trick-choice ?id ?trick ?p ?))
	=>
	(println "Player " ?p "'s turn")
	(loop-for-count (?c 1 (integer (/ (length$ ?cards) 2))) do
		(bind ?name (+ (* (- ?c 1) 2) 1))
		(bind ?suite (+ ?name 1))
		(println ?c ": " (nth$ ?name ?cards) " of " (nth$ ?suite ?cards)))
	(print "choice: ")
	(assert (trick-choice ?id ?trick ?p (read))))

(defrule leading-suite
	(dealer ?d)
	?h <- (hand ?id ?p&:(= ?p (+ ?d 1)) $?cards)
	(trick ?id ?t ?p)
	(trick-choice ?id ?t ?p ?c)
	(not (trick-choice-card ?id ?t ?p ? ?))
	=>
	(retract ?h)
	(bind ?name (+ (* (- ?c 1) 2) 1))
	(bind ?suite (+ ?name 1))
	(println crlf "Player " ?p " plays " (nth$ ?name ?cards) " of " (nth$ ?suite ?cards) crlf)
	(println "Leading suite is " (nth$ ?suite ?cards) crlf)
	(assert
		(trick-choice-card ?id ?t ?p (nth$ ?name ?cards) (nth$ ?suite ?cards))
		(hand ?id ?p (delete$ ?cards ?name ?suite))
		(leading-suite ?id ?t (nth$ ?suite ?cards))
		(trick ?id ?t (+ ?p 1))))

(defrule bad-trick-choice
	(trick ?id ?trick ?p)
	(hand ?id ?p $?cards)
	?t <- (trick-choice ?id ?trick ?p ?c&:(or (> ?c (/ (length$ ?cards) 2)) (< ?c 1)))
	(not (trick-choice-card ?id ?trick ?p ? ?))
	=>
	(retract ?t)
	(println "error ERROR: Please enter a number 1 thru " (/ (length$ ?cards) 2)))

(defrule trick-choice-out-of-leading-suite
	(dealer ?id ?d)
	(hand ?id ?p $?cards)
	(leading-suite ?id ?trick ?suite)
	(trick ?id ?trick ?p)
	?t <- (trick-choice ?id ?trick ?p ?c)
	(not (trick-choice-card ?id ?trick ?p ? ?))
	(test (and
		(neq (nth$ (* ?c 2) ?cards) ?suite)
		(member$ ?suite ?cards)))
	=>
	(retract ?t)
	(println "error ERROR: You cannot use an out-of-suite card when you have cards in the leading suite."))

(defrule valid-trick-choice
	(game (id ?gid))
	(dealer ?gid ?d)
	(trick-choice-card ?gid ?trick ?l&:(= ?l (+ 1 ?d)) ? ?suite)
	?h <- (hand ?gid ?p&:(<> ?p ?l) $?cards)
	(trick ?gid ?t ?p)
	(trick-choice ?gid ?t ?p ?c&:(and (>= ?c 1) (<= ?c (/ (length$ ?cards) 2))))
	(not (trick-choice-card ?gid ?t ?p ? ?))
	(test (or
		(eq (nth$ (* ?c 2) ?cards) ?suite)
		(not (member$ ?suite ?cards))))
	=>
	(retract ?h)
	(bind ?name (+ (* (- ?c 1) 2) 1))
	(bind ?suite (+ ?name 1))
	(broadcast ?gid (format nil "cardinplay %n %s %s" ?p (nth$ ?name ?cards) (nth$ ?suite ?cards)))
	(broadcast ?gid (format nil "say Player %n plays %s of %s" ?p (nth$ ?name ?cards) (nth$ ?suite ?cards)))
	(println crlf "Player " ?p " plays " (nth$ ?name ?cards) " of " (nth$ ?suite ?cards) crlf)
	(assert
		(trick-choice-card ?gid ?t ?p (nth$ ?name ?cards) (nth$ ?suite ?cards))
		(hand ?gid ?p (delete$ ?cards ?name ?suite))
		(trick ?gid ?t (+ ?p 1))))

(defrule score-trick-choice-card-trump-left-bower
	(trump-suite ?id ?t ?suite)
	(trick-choice-card ?id ?t ?p jack ?suite)
	(forall (hand ?id ?h $?) (trick-choice-card ?id ?t ?h ? ?))
	=>
	(assert (trick-winner ?id ?t ?p)))

(defrule score-trick-choice-card-trump-right-bower
	(opposites ?suite ?s)
	(trump-suite ?id ?t ?suite)
	(trick-choice-card ?id ?t ?p jack ?s)
	(not (trick-choice-card ?id ?t ? jack ?suite))
	(forall (hand ?id ?h $?) (trick-choice-card ?id ?t ?h ? ?))
	=>
	(assert (trick-winner ?id ?t ?p)))

(defrule score-trick-choice-card-trump
	(opposites ?suite ?s)
	(card-score ?name ?value)
	(trump-suite ?id ?t ?suite)
	(trick-choice-card ?id ?t ?p ?name&~jack ?suite)
	(not (trick-choice-card ?id ?t ~?p jack ?suite|?s))
	(not (and (card-score ?n ?v) (trick-choice-card ?id ?t ? ?n&:(> ?v ?value) ?suite)))
	(forall (hand ?id ?h $?) (trick-choice-card ?id ?t ?h ? ?))
	=>
	(assert (trick-winner ?id ?t ?p)))

(defrule score-trick-choice-card-leading
	(opposites ?s ?os)
	(card-score ?name ?value)
	(dealer ?id ?d)
	(trump-suite ?id ?t ?s)
	(leading-suite ?id ?t ?suite&~?s)
	(trick-choice-card ?id ?t ?p ?name ?suite)
	(not (trick-choice-card ?id ? ? ? ?s))
	(not (trick-choice-card ?id ? ? jack ?os))
	(not (and (card-score ?n ?v) (trick-choice-card ?id ?t ? ?n&:(> ?v ?value) ?suite)))
	(forall (hand ?id ?h $?) (trick-choice-card ?id ?t ?h ? ?))
	=>
	(assert (trick-winner ?id ?t ?p)))

(defrule shuffle
	?u <- (unshuffled-deck ?id $?cards&:(> (length$ ?cards) 0))
	?s <- (shuffled-deck ?id $?start)
	=>
	(retract ?s ?u)
	(bind ?suite (* (random 1 (integer (/ (length$ ?cards) 2))) 2))
	(bind ?name (- ?suite 1))
	(assert
	 (shuffled-deck ?id ?start (nth$ ?name ?cards) (nth$ ?suite ?cards))
	 (unshuffled-deck ?id (delete$ ?cards ?name ?suite))))
