class_name JokerEcho
extends JokerDef
## Counter-joker. The FIRST buff card you trigger each round fires again — so
## reading which humble property is secretly buffed, and hitting it first, pays
## double. Rewards the intended play (find the buff, lead with it).

func echo_count() -> int:
	return int(num("echo", 1.0))
