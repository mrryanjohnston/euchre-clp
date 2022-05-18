(deftemplate card-in-hand
	(slot player)
	(slot name)
	(slot suit)
	(slot choice (default 0)))

(deftemplate card-in-play
	(slot player)
	(slot name)
	(slot suit)
	(slot trick)
	(slot choice (default 0)))

(deffacts setup
	(suit 1 ♥hearts)
	(suit 2 ♦diamonds)
	(suit 3 ♣clubs)
	(suit 4 ♠spades)
	(dealer 1)
	(dealt-round 0)
	(player 1)
	(player-to-the-right-of 1 2)
	(player 2)
	(player-to-the-right-of 2 3)
	(player 3)
	(player-to-the-right-of 3 4)
	(player 4)
	(player-to-the-right-of 4 1)
	(team-score 1 0)
	(team-score 2 0)
	(team-tricks-taken 1 0)
	(team-tricks-taken 2 0)
	(team-member 1 1)
	(team-member 1 3)
	(team-member 2 2)
	(team-member 2 4)
	(opposite-suit ♣clubs ♠spades)
	(opposite-suit ♠spades ♣clubs)
	(opposite-suit ♥hearts ♦diamonds)
	(opposite-suit ♦diamonds ♥hearts)
	(card-value 9 9)
	(card-value 10 10)
	(card-value jack 11)
	(card-value queen 12)
	(card-value king 13)
	(card-value ace 14)
	(shuffled-deck)
	(unshuffled-deck
		9 ♣clubs
		10 ♣clubs
		jack ♣clubs
		queen ♣clubs
		king ♣clubs
		ace ♣clubs
		9 ♠spades
		10 ♠spades
		jack ♠spades
		queen ♠spades
		king ♠spades
		ace ♠spades
		9 ♦diamonds
		10 ♦diamonds
		jack ♦diamonds
		queen ♦diamonds
		king ♦diamonds
		ace ♦diamonds
		9 ♥hearts
		10 ♥hearts
		jack ♥hearts
		queen ♥hearts
		king ♥hearts
		ace ♥hearts))

(defrule start-dealing
	(dealer ?d)
	(player-to-the-right-of ?d ?p)
	?u <- (unshuffled-deck $?cards&:(= (length$ ?cards) 48))
	?s <- (shuffled-deck $?scards)
	=>
	(retract ?s ?u)
	(bind ?ii (* (random 1 24) 2))
	(bind ?i (- ?ii 1))
	(assert
		(card-in-hand (player ?p) (name (nth$ ?i ?cards)) (suit (nth$ ?ii ?cards)))
		(shuffled-deck $?scards (nth$ ?i ?cards) (nth$ ?ii ?cards))
		(last-dealt ?p)
		(unshuffled-deck (delete$ ?cards ?i ?ii))))

(defrule continue-dealing
	(player-to-the-right-of ?p ?np)
	?l <- (last-dealt ?p)
	?u <- (unshuffled-deck $?cards&:(and (<= (length$ ?cards) 46) (> (length$ ?cards) 8)))
	?s <- (shuffled-deck $?scards)
	=>
	(retract ?l ?s ?u)
	(bind ?ii (* (random 1 (integer (/ (length$ ?cards) 2))) 2))
	(bind ?i (- ?ii 1))
	(assert
		(card-in-hand (player ?np) (name (nth$ ?i ?cards)) (suit (nth$ ?ii ?cards)))
		(shuffled-deck $?scards (nth$ ?i ?cards) (nth$ ?ii ?cards))
		(last-dealt ?np)
		(unshuffled-deck (delete$ ?cards ?i ?ii))))

(defrule done-dealing
	?d <- (dealt-round ?dealt)
	?l <- (last-dealt ?)
	(unshuffled-deck $?cards&:(= (length$ ?cards) 8))
	=>
	(retract ?d ?l)
	(assert
		(kitty)
		(dealt-round (+ ?dealt 1))))

(defrule kitty
	?u <- (unshuffled-deck $?cards&:(and (> (length$ ?cards) 0) (<= (length$ ?cards) 8)))
	?k <- (kitty $?kitty)
	?s <- (shuffled-deck $?scards)
	=>
	(retract ?k ?s ?u)
	(bind ?ii (* (random 1 (integer (/ (length$ ?cards) 2))) 2))
	(bind ?i (- ?ii 1))
	(assert
		(unshuffled-deck (delete$ ?cards ?i ?ii))
		(shuffled-deck $?scards (nth$ ?i ?cards) (nth$ ?ii ?cards))
		(kitty ?kitty (nth$ ?i ?cards) (nth$ ?ii ?cards))))

(defrule reveal-top-kitty-card-and-begin-bidding
	(dealer ?d)
	(player-to-the-right-of ?d ?p)
	(dealt-round ?dealt)
	(unshuffled-deck)
	(kitty ?name ?suit $?)
	(not (use-card-from-kitty-as-trump ?dealt ?p ?))
	=>
	(println "The top card from the kitty is " ?name " of " ?suit)
	(print "Does Player " ?p " want to use " ?suit " as trump suit? (y/n): ")
	(assert
		(last-bidder ?dealt ?p)
		(use-card-from-kitty-as-trump ?dealt ?p (read))))

(defrule bad-use-card-from-kitty-as-trump
	?u <- (use-card-from-kitty-as-trump ? ?p ~y&~n)
	=>
	(println "ERROR: bad choice")
	(retract ?u))

(defrule continue-bidding-on-top-kitty-card
	(player-to-the-right-of ?p ?np)
	(unshuffled-deck)
	(kitty ?name ?suit $?)
	(dealt-round ?dealt)
	?l <- (last-bidder ?dealt ?p)
	(use-card-from-kitty-as-trump ?dealt ?p n)
	(not (use-card-from-kitty-as-trump ?dealt ?np ?))
	=>
	(retract ?l)
	(print "Does Player " ?np " want to use " ?suit " as trump suit? (y/n): ")
	(assert
		(last-bidder ?dealt ?np)
		(use-card-from-kitty-as-trump ?dealt ?np (read))))

(defrule choose-trump
	(dealer ?d)
	(player-to-the-right-of ?d ?p)
	(unshuffled-deck)
	(dealt-round ?dealt)
	?k <- (kitty ?name ?suit $?kitty)
	?l <- (last-bidder ?dealt ?d)
	(forall (player ?pp) (use-card-from-kitty-as-trump ?dealt ?pp n))
	(not (player-chooses-trump-suit ?dealt ?p ?))
	(not (trump-suit ?dealt ? ?))
	=>
	(retract ?k ?l)
	(println "No one wanted to use " ?suit " as trump")
	(println "Returning the " ?name " of " ?suit " to bottom of kitty")
	(print "Does player " ?p " want to choose trump suit? (y/n): ")
	(assert
		(kitty ?kitty ?name ?suit)
		(last-bidder-choose ?dealt ?p)
		(player-chooses-trump-suit ?dealt ?p (read))))

(defrule bad-player-chooses-trump-suit
	(dealt-round ?dealt)
	?u <- (player-chooses-trump-suit ?dealt ?p ~y&~n)
	=>
	(retract ?u)
	(println "ERROR: bad choice")
	(print "Does player " ?p " want to choose trump suit? (y/n): ")
	(assert (player-chooses-trump-suit ?dealt ?p (read))))

(defrule choose-trump-pass
	(dealer ?d)
	(player-to-the-right-of ?p ?np&~?d)
	?l <- (last-bidder-choose ?dealt ?p)
	(player-chooses-trump-suit ?dealt ?p n)
	(not (player-chooses-trump-suit ?dealt ?np ?))
	=>
	(retract ?l)
	(print "Does player " ?np " want to choose trump suit? (y/n): ")
	(assert
		(last-bidder-choose ?dealt ?np)
		(player-chooses-trump-suit ?dealt ?np (read))))

(defrule screw-the-dealer
	(dealer ?d)
	(player-to-the-right-of ?p ?d)
	?l <- (last-bidder-choose ?dealt ?p)
	(player-chooses-trump-suit ?dealt ?p n)
	(not (player-chooses-trump-suit ?dealt ?d ?))
	=>
	(retract ?l)
	(println "Screw the dealer: Dealer must choose trump suit")
	(assert (player-chooses-trump-suit ?dealt ?d y)))

(defrule choose-trump-y
	(player-chooses-trump-suit ?dealt ?p y)
	(not (trump-suit-choice ?dealt ? ?))
	=>
	(println "Player " ?p " chooses a trump suit:")
	(println "1. ♥hearts")
	(println "2. ♦diamonds")
	(println "3. ♣clubs")
	(println "4. ♠spades")
	(print "(1-4): ")
	(assert (trump-suit-choice ?dealt ?p (read))))

(defrule illegal-trump-suit-choice
	?x <- (trump-suit-choice ?dealt ?p ~1&~2&~3&~4&~5)
	=>
	(println "ERROR: bad choice for trump suit")
	(println "Try again")
	(retract ?x))

(defrule trump-suit-choice
	(suit ?c ?s)
	(trump-suit-choice ?dealt ?p ?c)
	=>
	(println "Player " ?p " chooses " ?s " as trump suit")
	(assert (trump-suit ?dealt ?p ?s)))

(defrule pick-it-up
	(dealer ?d)
	(dealt-round ?dealt)
	?k <- (kitty ?name ?suit $?kitty)
	?l <- (last-bidder ?dealt ?p)
	(use-card-from-kitty-as-trump ?dealt ?p y)
	(not (trump-suit ?dealt ? ?))
	=>
	(println "Player " ?p " says \"pick it up\"")
	(println "Player " ?d " (the dealer) must now discard a card from their hand")
	(bind ?i 0)
	(do-for-all-facts ((?c card-in-hand)) (= ?c:player ?d) do
		(bind ?i (+ ?i 1))
		(modify ?c (choice ?i))
		(println ?c:choice ": " ?c:name " of " ?c:suit))
	(print "(1-" ?i "): ")
	(retract ?k ?l)
	(assert
		(dealer-chooses-this-card ?d (read))
		(dealer-gains-this-card ?d ?name ?suit)
		(kitty ?kitty)))

(defrule illegal-pick-it-up
	(dealer ?d)
	?x <- (dealer-chooses-this-card ?d ?choice)
	(not (card-in-hand (choice ?choice) (player ?d)))
	=>
	(println "ERROR: bad choice for card in hand to swap")
	(println "Try again")
	(do-for-all-facts ((?c card-in-hand)) (= ?c:player ?d) do
		(println ?c:choice ": " ?c:name " of " ?c:suit)
		(bind ?i ?c:choice))
	(print "(1-" ?i "): ")
	(retract ?x)
	(assert (dealer-chooses-this-card ?d (read))))

(defrule legal-pick-it-up
	(player-to-the-right-of ?d ?np)
	(dealer ?d)
	(dealt-round ?dealt)
	?k <- (kitty $?kitty)
	?card <- (card-in-hand (choice ?c) (player ?d) (name ?n) (suit ?s))
	(use-card-from-kitty-as-trump ?dealt ?p y)
	?choice <- (dealer-chooses-this-card ?d ?c)
	?gains <- (dealer-gains-this-card ?d ?name ?suit)
	=>
	(retract ?card ?choice ?gains ?k)
	(println "Player " ?d " (the dealer) gains " ?name " of " ?suit " to their hand")
	(println "Trump suit is " ?suit)
	(assert
		(card-in-hand (player ?d) (name ?name) (suit ?suit))
		(kitty ?kitty ?n ?s)
		(trump-suit ?dealt ?p ?suit)))

(defrule initialize-trick
	(player-to-the-right-of ?d ?l)
	(dealer ?d)
	(dealt-round ?dealt)
	(trump-suit ?dealt ? ?)
	=>
	(assert
		(trick ?dealt 1)
		(leader-of-trick ?dealt 1 ?l)))

(defrule determine-leading-suit
	(dealt-round ?dealt)
	(leader-of-trick ?dealt ?t&~6 ?p)
	(trick ?dealt ?t)
	(trump-suit ?dealt ? ?s)
	(not (leading-suit-choice ?dealt ?t ? ?))
	(not (leading-suit ?dealt ?t ? ?))
	=>
	(println "Player " ?p " plays a card that will become leading suit")
	(bind ?i 0)
	(do-for-all-facts ((?c card-in-hand)) (= ?c:player ?p) do
		(bind ?i (+ ?i 1))
		(modify ?c (choice ?i))
		(println ?c:choice ": " ?c:name " of " ?c:suit))
	(print "(1-" ?i "): ")
	(assert (leading-suit-choice ?dealt ?t ?p (read))))

(defrule illegal-leading-suit-choice
	(dealt-round ?dealt)
	(trick ?dealt ?t)
	?x <- (leading-suit-choice ?dealt ?t ?p ?choice)
	(not (card-in-hand (choice ?choice) (player ?p)))
	=>
	(println "ERROR: bad choice for leading suit")
	(println "Try again")
	(retract ?x))

(defrule leading-suit-choice
	(dealt-round ?dealt)
	(player-to-the-right-of ?p ?np)
	(trick ?dealt ?t)
	?l <- (leading-suit-choice ?dealt ?t ?p ?choice)
	?c <- (card-in-hand (choice ?choice) (suit ?s) (name ?name) (player ?p))
	(not (leading-suit ?dealt ?t ? ?))
	=>
	(retract ?c ?l)
	(println "Player " ?p " plays " ?name " of " ?s)
	(println ?s " is now the leading suit")
	(assert
		(leading-suit ?dealt ?t ?p ?s)
		(card-in-play (trick ?t) (choice ?choice) (suit ?s) (name ?name) (player ?p))
		(next-player-turn ?t ?np)))

(defrule play-next-card
	(player-to-the-right-of ?pp ?p)
	(dealt-round ?dealt)
	(trick ?dealt ?t)
	?n <- (next-player-turn ?t ?p)
	(card-in-play (trick ?t) (player ?pp))
	(not (card-in-play (player ?p)))
	=>
	(println "Player " ?p " plays a card from their hand")
	(bind ?i 0)
	(do-for-all-facts ((?c card-in-hand)) (= ?c:player ?p) do
		(bind ?i (+ ?i 1))
		(modify ?c (choice ?i))
		(println ?c:choice ": " ?c:name " of " ?c:suit))
	(print "(1-" ?i "): ")
	(assert (card-to-play ?t ?p (read))))

(defrule illegal-play-next-card
	?x <- (card-to-play ?t ?p ?choice)
	(not (card-in-hand (choice ?choice) (player ?p)))
	=>
	(println "ERROR: card not in hand")
	(println "Try again")
	(do-for-all-facts ((?c card-in-hand)) (= ?c:player ?p) do
		(println ?c:choice ": " ?c:name " of " ?c:suit)
		(bind ?i ?c:choice))
	(print "(1-" ?i "): ")
	(retract ?x)
	(assert (card-to-play ?t ?p (read))))

(defrule legal-play-next-card
	(player-to-the-right-of ?p ?np)
	?n <- (next-player-turn ?t ?p)
	?c <- (card-in-hand (choice ?choice) (player ?p) (name ?name) (suit ?suit))
	?tp <- (card-to-play ?t ?p ?choice)
	(not (card-in-play (trick ?t) (player ?p)))
	=>
	(retract ?c ?n ?tp)
	(println "Player " ?p " plays " ?name " of " ?suit)
	(assert
		(card-in-play (trick ?t) (choice ?choice) (suit ?suit) (name ?name) (player ?p))
		(next-player-turn ?t ?np)))

(defrule trump-jack-wins
	(dealt-round ?dealt)
	(trick ?dealt ?t)
	?n <- (next-player-turn ?t ?)
	(trump-suit ?dealt ? ?s)
	(card-in-play (trick ?t) (player ?p) (name jack) (suit ?s))
	(forall (player ?pp) (card-in-play (trick ?t) (player ?pp)))
	=>
	(retract ?n)
	(assert (trick-winner ?dealt ?t ?p)))

(defrule opposite-jack-wins
	(opposite-suit ?s ?os)
	(dealt-round ?dealt)
	(trick ?dealt ?t)
	?n <- (next-player-turn ?t ?)
	(trump-suit ?dealt ? ?s)
	(card-in-play (trick ?t) (player ?p) (name jack) (suit ?os))
	(not (card-in-play (trick ?t) (player ?p) (name jack) (suit ?s)))
	(forall (player ?pp) (card-in-play (trick ?t) (player ?pp)))
	=>
	(retract ?n)
	(assert (trick-winner ?dealt ?t ?p)))

(defrule highest-trump-wins
	(card-value ?name ?value)
	(opposite-suit ?s ?os)
	(dealt-round ?dealt)
	(trick ?dealt ?t)
	?n <- (next-player-turn ?t ?)
	(trump-suit ?dealt ? ?s)
	(card-in-play (trick ?t) (player ?p) (name ?name) (suit ?s))
	(not (and
		(card-value ?oname ?ovalue)
		(card-in-play (trick ?t) (player ~?p) (name ?oname&:(> ?ovalue ?value)) (suit ?s))))
	(not (card-in-play (trick ?t) (name jack) (suit ?os)))
	(not (card-in-play (trick ?t) (name jack) (suit ?s)))
	(forall (player ?pp) (card-in-play (trick ?t) (player ?pp)))
	=>
	(retract ?n)
	(assert (trick-winner ?dealt ?t ?p)))

(defrule highest-leading-wins
	(card-value ?name ?value)
	(opposite-suit ?s ?os)
	(dealt-round ?dealt)
	(trick ?dealt ?t)
	?n <- (next-player-turn ?t ?)
	(trump-suit ?dealt ? ?s)
	(leading-suit ?dealt ?t ? ?ls)
	(card-in-play (trick ?t) (player ?p) (name ?name) (suit ?ls))
	(not (and
		(card-value ?oname ?ovalue)
		(card-in-play (trick ?t) (player ~?p) (name ?oname&:(> ?ovalue ?value)) (suit ?ls))))
	(not (card-in-play (trick ?t) (name jack) (suit ?os)))
	(not (card-in-play (trick ?t) (suit ?s)))
	(forall (player ?pp) (card-in-play (trick ?t) (player ?pp)))
	=>
	(retract ?n)
	(assert (trick-winner ?dealt ?t ?p)))

(defrule trick-winner
	(dealt-round ?dealt)
	(team-member ?team ?p)
	?f <- (team-tricks-taken ?team ?taken)
	(trick-winner ?dealt ?t ?p)
	(card-in-play (trick ?t) (player ?p) (name ?n) (suit ?s))
	?c1 <- (card-in-play (trick ?t) (player 1) (name ?n1) (suit ?s1))
	?c2 <- (card-in-play (trick ?t) (player 2) (name ?n2) (suit ?s2))
	?c3 <- (card-in-play (trick ?t) (player 3) (name ?n3) (suit ?s3))
	?c4 <- (card-in-play (trick ?t) (player 4) (name ?n4) (suit ?s4))
	=>
	(retract ?c1 ?c2 ?c3 ?c4 ?f)
	(println "Player " ?p " takes the trick with " ?n " of " ?s "!")
	(assert
		(trick-cards ?t ?n1 ?s1 ?n2 ?s2 ?n3 ?s3 ?n4 ?s4)
		(team-tricks-taken ?team (+ ?taken 1))
		(trick ?dealt (+ ?t 1))
		(leader-of-trick ?dealt (+ ?t 1) ?p)))

(defrule makers-low
	(dealt-round ?dealt)
	(leader-of-trick 6 ?)
	?taken <- (team-tricks-taken ?team ?tricks&3|4)
	?other <- (team-tricks-taken ?oteam&~?team ?)
	?f <- (team-score ?team ?score)
	(team-member ?team ?p)
	(team-member ?team ?op)
	(trump-suit ?dealt ?p|?op ?)
	=>
	(retract ?f ?taken ?other)
	(println "Makers take " ?tricks " tricks and win 1 point")
	(assert
		(scored-round ?dealt)
		(team-tricks-taken ?team 0)
		(team-tricks-taken ?oteam 0)
		(team-score ?team (+ ?score 1))))

(defrule makers-high
	(dealt-round ?dealt)
	(leader-of-trick ?dealt 6 ?)
	?taken <- (team-tricks-taken ?team 5)
	?other <- (team-tricks-taken ?oteam&~?team ?)
	?f <- (team-score ?team ?score)
	(team-member ?team ?p)
	(team-member ?team ?op)
	(trump-suit ?dealt ?p|?op ?)
	=>
	(retract ?f ?taken ?other)
	(println "Makers take 5 tricks and win 2 points")
	(assert
		(scored-round ?dealt)
		(team-tricks-taken ?team 0)
		(team-tricks-taken ?oteam 0)
		(team-score ?team (+ ?score 2))))

(defrule defenders
	(dealt-round ?dealt)
	(leader-of-trick ?dealt 6 ?)
	?taken <- (team-tricks-taken ?team ?tricks&3|4|5)
	?other <- (team-tricks-taken ?oteam&~?team ?)
	?f <- (team-score ?team ?score)
	(team-member ?team ?p)
	(team-member ?team ?op)
	(trump-suit ?dealt ~?p&~?op ?)
	=>
	(retract ?f ?taken ?other)
	(println "Defenders take " ?tricks " tricks and win 2 points")
	(assert
		(scored-round ?dealt)
		(team-tricks-taken ?team 0)
		(team-tricks-taken ?oteam 0)
		(team-score ?team (+ ?score 2))))

(defrule reshuffle
	(player-to-the-right-of ?dealer ?nd)
	?d <- (dealer ?dealer)
	(dealt-round ?dealt)
	(scored-round ?dealt)
	?k <- (kitty $?)
	?s <- (shuffled-deck $?cards)
	?u <- (unshuffled-deck)
	(not (team-score ? ?score&:(>= ?score 10)))
	=>
	(retract ?d ?k ?s ?u)
	(assert
		(dealer ?nd)
		(shuffled-deck)
		(unshuffled-deck ?cards)))

(defrule declare-winner
	(dealt-round ?dealt)
	(scored-round ?dealt)
	(team-score ?team ?score&:(>= ?score 10))
	=>
	(println "Team " ?team " wins with a score of " ?score "!"))
