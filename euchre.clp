(deftemplate card-in-hand
	(slot game)
	(slot seat)
	(slot name)
	(slot suit))
(deftemplate card-in-play
	(slot game)
	(slot seat)
	(slot name)
	(slot suit))
(deftemplate game
	(slot id)
	(slot started (default FALSE)))
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
	(assert (session ?sid) (name ?sid ?sid)))

(defrule connection
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	=>
	(println "[euchre.clp] User " ?sid " connected on websocket " ?wsid)
	(format ?wsid "id %s" ?sid))

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

(defrule setname
	(connection (sid ?sid) (wsid ?wsid))
	?n <- (name ?sid ?name)
	?s <- (parsed-message-from ?wsid setname $?msg&:(< (str-length (implode$ ?msg)) 16))
	=>
	(retract ?n ?s)
	(assert (name ?sid (implode$ ?msg))))

(defrule setname-too-long
	(connection (sid ?sid) (wsid ?wsid))
	(name ?sid ?name)
	?s <- (parsed-message-from ?wsid setname $?msg&:(> (str-length (implode$ ?msg)) 15))
	=>
	(retract ?s)
	(format ?wsid "error ERROR: Name too long; please choose something less than 15 characters"))

(defrule successful-setname
	(connection (sid ?sid) (wsid ?wsid))
	(name ?sid ?name)
	=>
	(format ?wsid "is %s %s" ?sid ?name))

(defrule is-name
	(name ?sid ?name)
	(connection (sid ?sid) (wsid ?wsid))
	(connection (sid ?ssid&~?sid) (wsid ?wwsid))
	(game (id ?gid))
	=>
	(format ?wwsid "is %s %s" ?sid ?name))

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
	(broadcast ?gid (format nil "spectate %s" ?sid))
	(assert (spectator (game ?gid) (sid ?sid))))

(defrule leave-game
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	?g <- (game-connection (game ?gid) (wsid ?wsid))
	?s <- (parsed-message-from ?wsid leave)
	=>
	(retract ?g ?s)
	(printout ?wsid leave))

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

(defrule not-connected-to-a-game-to-leave
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	?s <- (parsed-message-from ?wsid leave)
	(not (game-connection (wsid ?wsid)))
	=>
	(printout ?wsid "error ERROR: Could not leave game; not currently in one")
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
	(game-connection (game ?gid) (wsid ?wsid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	=>
	(format ?wsid "sit %s %d" ?sid ?seat))

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
	(game (id ?gid) (started FALSE))
	?pl <- (player (game ?gid) (seat ?seat) (sid ?sid))
	?p <- (parsed-message-from ?wsid stand)
	=>
	(retract ?pl ?p)
	(assert (spectator (game ?gid) (sid ?sid)))
	(broadcast ?gid (format nil "stand %s %d" ?sid ?seat)))

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

(defrule cannot-stand-after-game-started
	(session ?sid)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid) (started TRUE))
	(player (game ?gid) (sid ?sid))
	?p <- (parsed-message-from ?wsid stand)
	(game-connection (game ?gid) (wsid ?wsid))
	=>
	(printout ?wsid "error ERROR: Could not stand; game has begun")
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
	?g <- (game (id ?id) (started FALSE))
	(player (game ?id) (seat 1))
	(player (game ?id) (seat 2))
	(player (game ?id) (seat 3))
	(player (game ?id) (seat 4))
	=>
	(modify ?g (started TRUE))
	(assert
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

(defrule tell-own-card-in-hand
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	(player (game ?gid) (seat ?s) (sid ?sid))
	(card-in-hand (game ?gid) (seat ?s) (name ?name) (suit ?suit))
	=>
	(format ?wsid "cardinhand %d %s %s" ?s (sym-cat ?name) ?suit))

(defrule tell-other-card-in-hand
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	(card-in-hand (game ?gid) (seat ?ss))
	(or (player (game ?gid) (seat ?s&~?ss) (sid ?sid))
	    (spectator (game ?gid) (sid ?sid)))
	=>
	(format ?wsid "cardinhand %d" ?ss))

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
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	(unshuffled-deck ?gid)
	?k <- (kitty ?gid $? ?name ?suit)
	(dealt-round ?gid ?dealt)
	=>
	(printout ?wsid kitty)
	(printout ?wsid kitty)
	(printout ?wsid kitty)
	(format ?wsid "kitty %s %s" (sym-cat ?name) ?suit))

(defrule start-kitty-bidding
	(player-to-the-left-of ?d ?p)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(dealer ?gid ?d)
	(player (game ?gid) (seat ?p) (sid ?sid))
	(game-connection (game ?gid) (wsid ?wsid))
	(not (expected-bidder ?gid ?))
	(not (trump-suit ?gid ?))
	=>
	(assert (expected-bidder ?gid ?p))
	(printout ?wsid "bid"))

(defrule announce-bidder
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-bidder ?gid ?p)
	(not (bid ?gid ?p ?))
	(not (all-pass ?gid ?))
	(not (trump-suit ?gid ?))
	=>
	(format ?wsid "bidder %d" ?p))

(defrule bad-bid
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-bidder ?gid ?seat)
	?p <- (parsed-message-from ?wsid bid $? ~yes&~no)
	=>
	(printout ?wsid "error ERROR: bad choice")
	(retract ?p))

(defrule bad-bidder
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-bidder ?gid ~?seat)
	?p <- (parsed-message-from ?wsid bid $?)
	=>
	(printout ?wsid "error ERROR: it's not your turn to bid")
	(retract ?p))

(defrule bid-is-no
	(player-to-the-left-of ?seat ?np)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	?e <- (expected-bidder ?gid ?seat)
	?p <- (parsed-message-from ?wsid bid no)
	(not (bid ?gid ?seat ?))
	=>
	(retract ?e ?p)
	(assert
		(bid ?gid ?seat pass)
		(expected-bidder ?gid ?np)))

(defrule bid-is-yes
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-bidder ?gid ?seat)
	?p <- (parsed-message-from ?wsid bid yes)
	(not (bid ?gid ?seat ?))
	=>
	(retract ?p)
	(assert (bid ?gid ?seat pick-it-up)))

(defrule pick-it-up
	(team-member ?team ?seat)
	(team-tricks-taken ?gid ?oteam&~?team ?)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	(kitty ?gid $? ?name ?suit)
	(bid ?gid ?seat pick-it-up)
	(not (trump-suit ?gid ?))
	=>
	(assert
		(trump-suit ?gid ?suit)
		(makers ?gid ?team)
		(defenders ?gid ?oteam)))

(defrule announce-trump-suit
	(game-connection (game ?gid) (wsid ?wsid))
	(trump-suit ?gid ?suit)
	=>
	(format ?wsid "trump %s" ?suit))

(defrule clean-up-bid-facts-after-trump-chosen
	(game (id ?gid))
	?b <- (bid ?gid ? ?)
	(trump-suit ?gid ?)
	=>
	(retract ?b))

(defrule clean-up-expected-bidder-facts-after-trump-chosen
	(game (id ?gid))
	?e <- (expected-bidder ?gid ?)
	(trump-suit ?gid ?)
	=>
	(retract ?e))

(defrule clean-up-expected-trump-selector-facts-after-trump-chosen
	(game (id ?gid))
	?e <- (expected-trump-selector ?gid ?p)
	(trump-suit ?gid ?)
	=>
	(retract ?e))

(defrule all-pass
	(game (id ?gid))
	(kitty ?gid $? ?name ?suit)
	(forall (player (game ?gid) (seat ?s))
		(bid ?gid ?s pass))
	=>
	(assert (all-pass ?gid ?suit)))

(defrule announce-all-pass
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	(all-pass ?gid ?suit)
	=>
	(printout ?wsid "bidder")
	(format ?wsid "allpass %s" ?suit))

(defrule start-trump-selection
	(player-to-the-left-of ?d ?p)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(dealer ?gid ?d)
	(player (game ?gid) (seat ?p) (sid ?sid))
	(game-connection (game ?gid) (wsid ?wsid))
	(all-pass ?gid ?suit)
	(not (expected-trump-selector ?gid ?))
	(not (trump-suit ?gid ?))
	=>
	(assert (expected-trump-selector ?gid ?p))
	(format ?wsid "allpass %s" ?suit)
	(printout ?wsid "trumpselection"))

(defrule announce-trump-selector
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-trump-selector ?gid ?p)
	(not (trump-selection ?gid ?p ?))
	=>
	(format ?wsid "trumpselector %d" ?p))

(defrule announce-screw-the-dealer
	(connection (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	(dealer ?gid ?d)
	(expected-trump-selector ?gid ?d)
	=>
	(format ?wsid "screwthedealer"))

(defrule bad-screw-the-dealer-selection-no
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(dealer ?gid ?seat)
	?p <- (parsed-message-from ?wsid trump $? no)
	=>
	(printout ?wsid "error ERROR: bad choice; dealer MUST choose trump suit")
	(retract ?p))

(defrule bad-trump-selection
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(dealer ?gid ~?seat)
	(expected-trump-selector ?gid ?seat)
	?p <- (parsed-message-from ?wsid trump $? ~hearts&~diamonds&~clubs&~spades&~no)
	=>
	(printout ?wsid "error ERROR: bad choice")
	(retract ?p))

(defrule bad-trump-selection-all-pass-selected
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(all-pass ?gid ?suit)
	(expected-trump-selector ?gid ?seat)
	?p <- (parsed-message-from ?wsid trump $? ?suit)
	=>
	(printout ?wsid "error ERROR: bad choice; cannot choose suit that was passed upon during bidding")
	(retract ?p))

(defrule bad-trump-selector
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-trump-selector ?gid ~?seat)
	?p <- (parsed-message-from ?wsid trump $?)
	=>
	(printout ?wsid "error ERROR: it's not your turn to select trump")
	(retract ?p))

(defrule trump-selection-is-no
	(player-to-the-left-of ?seat ?np)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(dealer ?gid ~?seat)
	?e <- (expected-trump-selector ?gid ?seat)
	?p <- (parsed-message-from ?wsid trump no)
	(not (trump-selection ?gid ?seat ?))
	=>
	(retract ?e ?p)
	(assert
		(trump-selection ?gid ?seat pass)
		(expected-trump-selector ?gid ?np)))

(defrule trump-selection-is-valid-suit
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	?a <- (all-pass ?gid ?suit)
	?e <- (expected-trump-selector ?gid ?seat)
	?p <- (parsed-message-from ?wsid trump
		?choice&~?suit&~no&hearts|diamons|clubs|spades)
	(not (trump-selection ?gid ?seat ?))
	=>
	(retract ?a ?e ?p)
	(assert (trump-suit ?gid ?choice)))

(defrule initialize-trick
	(player-to-the-left-of ?d ?np)
	(game (id ?gid))
	(dealer ?gid ?d)
	(trump-suit ?gid ?trump)
	(not (expected-player ?gid ?))
	=>
	(assert (expected-player ?gid ?np)))

(defrule announce-expected-player
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-player ?gid ?p)
	=>
	(format ?wsid "expectedplayer %d" ?p))

(defrule play-out-of-turn
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-player ?gid ~?seat)
	?p <- (parsed-message-from ?wsid play $?)
	=>
	(retract ?p)
	(printout ?wsid "error ERROR: it is not your turn to play"))

(defrule play-card-not-in-hand
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	(expected-player ?gid ?seat)
	?p <- (parsed-message-from ?wsid play $? ?name ?suit)
	(not (card-in-hand (game ?gid) (seat ?seat) (name ?name) (suit ?suit)))
	=>
	(retract ?p)
	(printout ?wsid "error ERROR: that card is not in your hand"))

(defrule play
	(player-to-the-left-of ?seat ?np)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(player (game ?gid) (sid ?sid) (seat ?seat))
	(game-connection (game ?gid) (wsid ?wsid))
	?c <- (card-in-hand (game ?gid) (seat ?seat) (name ?name) (suit ?suit))
	?e <- (expected-player ?gid ?seat)
	?p <- (parsed-message-from ?wsid play $? ?name ?suit)
	(not (card-in-play (game ?gid) (seat ?seat)))
	=>
	(retract ?c ?e ?p)
	(send-directly-to-player ?gid ?seat (format nil "play %d %s %s" ?seat (sym-cat ?name) ?suit))
	(broadcast-to-other-players ?gid ?seat (format nil "play %d" ?seat))
	(assert
		(card-in-play (game ?gid) (seat ?seat) (name ?name) (suit ?suit))
		(expected-player ?gid ?np)))

(defrule announce-leading-suit
	(player-to-the-left-of ?d ?seat)
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(dealer ?gid ?d)
	(player (game ?gid) (sid ?sid))
	(game-connection (game ?gid) (wsid ?wsid))
	(card-in-play (game ?gid) (seat ?seat) (suit ?suit))
	=>
	(format ?wsid "leadingsuit %s" ?suit))

(defrule announce-card-in-play
	(connection (sid ?sid) (wsid ?wsid))
	(game (id ?gid))
	(game-connection (game ?gid) (wsid ?wsid))
	(card-in-play (game ?gid) (seat ?seat) (suit ?suit) (name ?name))
	=>
	(format ?wsid "cardinplay %d %s %s" ?seat (sym-cat ?name) ?suit))

(defrule trump-jack-wins
	(trump-suit ?gid ?suit)
	(card-in-play (game ?gid) (seat 1))
	(card-in-play (game ?gid) (seat 2))
	(card-in-play (game ?gid) (seat 3))
	(card-in-play (game ?gid) (seat 4))
	(card-in-play (game ?gid) (seat ?seat) (name jack) (suit ?suit))
	=>
	(assert (trick-winner ?gid ?seat)))

(defrule opposite-jack-wins
	(opposite-suit ?suit ?os)
	(trump-suit ?gid ?suit)
	(card-in-play (game ?gid) (seat 1))
	(card-in-play (game ?gid) (seat 2))
	(card-in-play (game ?gid) (seat 3))
	(card-in-play (game ?gid) (seat 4))
	(card-in-play (seat ?seat) (name jack) (suit ?os))
	(not (card-in-play (name jack) (suit ?suit)))
	=>
	(assert (trick-winner ?gid ?seat)))

(defrule highest-trump-wins
	(card-value ?name ?value)
	(opposite-suit ?s ?os)
	(trump-suit ?gid ?s)
	(card-in-play (game ?gid) (seat 1))
	(card-in-play (game ?gid) (seat 2))
	(card-in-play (game ?gid) (seat 3))
	(card-in-play (game ?gid) (seat 4))
	(card-in-play (game ?gid) (seat ?seat) (name ?name) (suit ?s))
	(not (and
		(card-value ?oname ?ovalue)
		(card-in-play (game ?gid) (name ?oname&:(> ?ovalue ?value)) (suit ?s))))
	(not (card-in-play (name jack) (suit ?os)))
	(not (card-in-play (name jack) (suit ?s)))
	=>
	(assert (trick-winner ?gid ?seat)))

(defrule highest-lead-wins
        (player-to-the-left-of ?d ?p)
	(card-value ?name ?value)
	(opposite-suit ?s ?os)
	(dealer ?gid ?d)
	(trump-suit ?gid ?s)
	(card-in-play (game ?gid) (seat 1))
	(card-in-play (game ?gid) (seat 2))
	(card-in-play (game ?gid) (seat 3))
	(card-in-play (game ?gid) (seat 4))
	(card-in-play (game ?gid) (seat ?p) (suit ?suit))
	(card-in-play (game ?gid) (seat ?seat) (name ?name) (suit ?suit))
	(not (and
		(card-value ?oname ?ovalue)
		(card-in-play (game ?gid) (name ?oname&:(> ?ovalue ?value)) (suit ?s))))
	(not (card-in-play (name jack) (suit ?os)))
	(not (card-in-play (suit ?s)))
	=>
	(assert (trick-winner ?gid ?seat)))

(defrule trick-winner
	(team-member ?team ?p)
	?f <- (team-tricks-taken ?gid ?team ?taken)
	(team-tricks-taken ?gid ~?team ?otaken)
	(trick-winner ?gid ?p)
	(card-in-play (game ?gid) (seat ?p) (name ?n) (suit ?s))
	?c1 <- (card-in-play (game ?gid) (seat 1) (name ?n1) (suit ?s1))
	?c2 <- (card-in-play (game ?gid) (seat 2) (name ?n2) (suit ?s2))
	?c3 <- (card-in-play (game ?gid) (seat 3) (name ?n3) (suit ?s3))
	?c4 <- (card-in-play (game ?gid) (seat 4) (name ?n4) (suit ?s4))
	=>
	(retract ?c1 ?c2 ?c3 ?c4 ?f)
	(println "Player " ?p " takes trick " (+ ?taken ?otaken) " with " ?n " of " ?s "!")
	(assert
		(trick-cards ?gid (+ ?taken ?otaken) ?n1 ?s1 ?n2 ?s2 ?n3 ?s3 ?n4 ?s4)
		(team-tricks-taken ?gid ?team (+ ?taken 1))))

(defrule announce-team-tricks-taken
	(game-connection (game ?gid) (wsid ?wsid))
	(team-tricks-taken ?gid ?team ?taken)
	=>
	(format ?wsid "teamtrickstaken %d %d" ?team ?taken))
