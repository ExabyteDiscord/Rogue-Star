//Ports Mail System from CHOMPStation PR7024, 7051, 7059, 7105, 7286, 7337, 7558
/obj/item/mail
	name = "mail"
	desc = "An officially postmarked, tamper-evident parcel regulated by CentComm and made of high-quality materials."
	icon = 'icons/obj/bureaucracy_rs.dmi'
	icon_state = "mail_small"
	item_flags = NOBLUDGEON
	w_class = ITEMSIZE_SMALL
	drop_sound = 'sound/items/drop/paper.ogg'
	pickup_sound = 'sound/items/pickup/paper.ogg'
	mouse_drag_pointer = MOUSE_ACTIVE_POINTER
	// Destination tagging for the mail sorter.
	var/sortTag = 0
	// Who this mail is for and who can open it.
	var/datum/weakref/recipient
	// How many goodies this mail contains.
	var/goodie_count = 1
	// Goodies which can be given to anyone.
	// Weight sum will be 1000
	var/list/generic_goodies = list(
		/obj/item/weapon/spacecash/c50 = 150,
		/obj/item/weapon/reagent_containers/food/drinks/cans/cola = 130,
		/obj/item/weapon/reagent_containers/food/snacks/chips = 130,
		/obj/item/weapon/reagent_containers/food/drinks/coffee = 125,
		/obj/item/weapon/reagent_containers/food/drinks/tea = 125,
		/obj/item/weapon/reagent_containers/food/drinks/glass2/coffeemug/nt = 100,
		/obj/item/weapon/spacecash/c100 = 75,
		/obj/item/weapon/spacecash/c200 = 50,
		/obj/item/weapon/spacecash/c500 = 25,
		/obj/item/weapon/spacecash/c1000 = 10,
	)
	// Overlays (pure fluff)
	// Does the letter have the postmark overlay?
	var/postmarked = TRUE
	// Does the letter have a stamp overlay?
	var/stamped = TRUE
	// List of all stamp overlays on the letter.
	var/list/stamps = list()
	// Maximum number of stamps on the letter.
	var/stamp_max = 1
	// Physical offset of stamps on the object. X direction.
	var/stamp_offset_x = 0
	// Physical offset of stamps on the object. Y direction.
	var/stamp_offset_y = 2
	var/opening = FALSE

/obj/item/mail/container_resist(mob/living/M)
	if(istype(M, /mob/living/voice)) return
	M.forceMove(get_turf(src))
	to_chat(M, span_warning("You climb out of \the [src]."))

/obj/item/mail/envelope
	name = "envelope"
	icon_state = "mail_large"
	goodie_count = 2
	stamp_max = 2
	stamp_offset_y = 5

/obj/item/mail/Initialize()
	. = ..()
	RegisterSignal(src, COMSIG_MOVABLE_DISPOSING, .proc/disposal_handling)
	// Icons
	// Add some random stamps.
	if(stamped == TRUE)
		var/stamp_count = rand(1, stamp_max)
		for(var/i = 1, i <= stamp_count, i++)
			stamps += list("stamp_[rand(2, 8)]")

/obj/item/mail/blank
	desc = "A blank envelope."
	description_info = "An object can be placed into the envelope, click on it with an empty hand to seal it. Alt-Click to retrieve the items from inside before sealing."
	stamped = FALSE
	postmarked = FALSE
	var/set_recipient = FALSE
	var/set_content = FALSE
	var/sealed = FALSE
	var/list/mail_recipients = list()

/obj/item/mail/blank/attackby(obj/item/W, mob/user)
	..()
	if(istype(W, /obj/item/weapon/pen) && sealed && !set_recipient)
		if(setRecipient(user))
			set_recipient = TRUE
		add_fingerprint(user)
		return

	if(!set_content && !sealed)
		if(!do_after(user, 1.5 SECONDS, target = user))
			set_content = FALSE
		user.drop_item()
		W.forceMove(src)
		to_chat(user, "<span class='notice'>Placed the [W] into the [src]</span>")
		set_content = TRUE
		description_info = "Click with an empty hand to seal it, or Alt-Click to retrieve the object out."
		return
	return

/obj/item/mail/proc/setRecipient(mob/user)
	var/list/recipients = list()
	for(var/mob/living/player in player_list)
		if(!player_is_antag(player.mind) && player.mind.show_in_directory)
			recipients += player

	recipients = tgui_input_list(usr, "Choose recipient", "Recipients", recipients, recipients)

	if(recipients)
		initialize_for_recipient(recipients, preset_goodies = TRUE)
		return TRUE

/obj/item/mail/blank/AltClick(mob/user)
	if(sealed)
		return

	for(var/obj/stuff as anything in contents)
		if(isitem(stuff))
			user.put_in_hands(stuff)
		else
			stuff.forceMove(drop_location())
	set_content = FALSE
	description_info = initial(description_info)

/obj/item/mail/blank/ShiftClick(mob/user)
	..()
	if(!sealed)
		var/sender = tgui_input_text(user, "Write name", "Name", user.name)
		if(sender)
			desc = "A signed envelope, from [sender]."

/obj/item/mail/blank/attack_self(mob/user)
	if(!sealed)
		to_chat(user, "<span class='notice'>Sealing the envelope...</span>")
		if(!do_after(user, 1.5 SECONDS, target = user))
			sealed = FALSE
		sealed = TRUE
		description_info = "Shift Click to add the sender's name to the envelope, or attack with a pen to set a receiver."
		return
	. = ..()

/obj/item/mail/update_icon()
	. = ..()
	var/bonus_stamp_offset = 0
	for(var/stamp in stamps)
		var/image/stamp_image = image(
			icon_state = stamp,
			pixel_x = stamp_offset_x,
			pixel_y = stamp_offset_y + bonus_stamp_offset
		)
		stamp_image.appearance_flags |= RESET_COLOR
		add_overlay(stamp_image)
		bonus_stamp_offset -= 5

	if(postmarked == TRUE)
		var/image/postmark_image = image(
			icon = icon,
			icon_state = "postmark",
			pixel_x = stamp_offset_x + rand(-4, 0),
			pixel_y = stamp_offset_y + rand(bonus_stamp_offset + 3, 1)
		)
		postmark_image.appearance_flags |= RESET_COLOR
		add_overlay(postmark_image)

/obj/item/mail/attackby(obj/item/W as obj, mob/user as mob)
	. = ..() // RS Edit, allows the mail bag to grab the mail.

	// Destination tagging
	if(istype(W, /obj/item/device/destTagger))
		var/obj/item/device/destTagger/O = W
		if(O.currTag)
			if(src.sortTag != O.currTag)
				to_chat(user, "<span class='notice'>You have labeled the destination as [O.currTag].</span>")
				if(!src.sortTag)
					src.sortTag = O.currTag
				playsound(src, 'sound/machines/twobeep.ogg', 50, 1)
			else
				to_chat(user, "<span class='warning'>The mail is already labeled for [O.currTag].</span>")
		else
			to_chat(user, "<span class='warning'>You need to set a destination first!</span>")
	return

/obj/item/mail/attack_self(mob/user)
	if(!unwrap(user))
		return FALSE
	return after_unwrap(user)

/obj/item/mail/proc/unwrap(mob/user)
	if(recipient && user != recipient)
		to_chat(user, "<span class='notice'>You can't open somebody's mail! That's <em>illegal</em></span>")
		return FALSE

	if(opening)
		to_chat(user, "<span class='notice'>You are already opening that!</span>")
		return FALSE

	opening = TRUE
	if(!do_after(user, 1.5 SECONDS, target = user))
		opening = FALSE
		return FALSE
	return TRUE

/obj/item/mail/proc/after_unwrap(mob/user)
	user.temporarilyRemoveItemFromInventory(src, TRUE)
	for(var/obj/stuff as anything in contents)
		if(isitem(stuff))
			user.put_in_hands(stuff)
		else
			stuff.forceMove(drop_location())
	playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
	qdel(src)

/obj/item/mail/proc/initialize_for_recipient(mob/new_recipient, var/preset_goodies = FALSE)
	recipient = new_recipient
	var/current_title = new_recipient.mind.role_alt_title ? new_recipient.mind.role_alt_title : new_recipient.mind.assigned_role
	name = "[initial(name)] for [new_recipient.real_name] ([current_title])"
	var/datum/job/this_job = SSjob.name_occupations[new_recipient.job]
	var/list/goodies = generic_goodies
	if(this_job)
		var/image/envelope = image(icon, icon_state)
		envelope.color = this_job.get_mail_color()
		add_overlay(envelope)
	if(!preset_goodies)
		var/list/job_goodies = this_job.get_mail_goodies(new_recipient, current_title)
		if(LAZYLEN(job_goodies))
			if(this_job.exclusive_mail_goodies)
				goodies = job_goodies
			else
				goodies += job_goodies

	if(!preset_goodies)
		for(var/iterator in 1 to goodie_count)
			var/target_good = pickweight(goodies)
			var/atom/movable/target_atom = new target_good(src)
			log_game("[key_name(new_recipient)] received [target_atom.name] in the mail ([target_good])")


	update_icon()
	return TRUE

/obj/item/mail/proc/disposal_handling(disposal_source, obj/structure/disposalholder/disposal_holder, obj/machinery/disposal/deliveryChute, hasmob)
	SIGNAL_HANDLER
	if(!hasmob)
		disposal_holder.destinationTag = sortTag

// Mail spawn for events
/datum/admins/proc/spawn_mail(var/object as text)
	set name = "Spawn Mail"
	set category = "Fun"
	set desc = "Type in partial name of item to put in mail."

	if(!check_rights(R_SPAWN)) return

	var/obj/item/mail/new_mail = new
	var/list/types = typesof(/atom)
	var/list/matches = new()
	var/list/recipients = list()

	for(var/path in types)
		if(findtext("[path]", object))
			matches += path

	if(matches.len==0)
		return
	var/chosen
	if(matches.len==1)
		chosen = matches[1]
	else
		chosen = tgui_input_list(usr, "Select an atom type", "Spawn Atom in Mail", matches)
		if(!chosen)
			return

	for(var/mob/living/player in player_list)
		recipients += player

	recipients = tgui_input_list(usr, "Choose recipient", "Recipients", recipients, recipients)

	if(recipients)
		new_mail.initialize_for_recipient(recipients, TRUE)
		new chosen(new_mail)

	var/shuttle_spawn = tgui_alert(usr, "Spawn mail at location or in the shuttle?", "Spawn mail", list("Location", "Shuttle"))
	if(shuttle_spawn == "Shuttle")
		SSmail.admin_mail += new_mail
		log_and_message_admins("spawned [chosen] inside an envelope at the shuttle")
	else
		var/obj/item/mail/ground_mail = new /obj/item/mail(usr.loc)
		ground_mail.initialize_for_recipient(recipients, TRUE)
		new chosen(ground_mail)
		log_and_message_admins("spawned [chosen] inside an envelope at ([usr.x],[usr.y],[usr.z])")

	feedback_add_details("admin_verb","SE")

// Mail Crate
/obj/structure/closet/crate/mail
	name = "mail crate"
	desc = "An official mail crate from CentComm"
	points_per_crate = 0
	closet_appearance = /decl/closet_appearance/crate/nanotrasen

/obj/structure/closet/crate/mail/full/Initialize()
	. = ..()
	var/list/mail_recipients = list()
	for(var/mob/living/carbon/human/alive in player_list)
		if(alive.stat != DEAD && alive.client && alive.client.inactivity <= 10 MINUTES)
			mail_recipients += alive
	for(var/iterator in 1 to storage_capacity)
		var/obj/item/mail/new_mail
		if(prob(70))
			new_mail = new /obj/item/mail(src)
		else
			new_mail = new /obj/item/mail/envelope(src)
		var/mob/living/carbon/human/mail_to
		if(mail_to)
			new_mail.initialize_for_recipient(mail_to)
			mail_recipients -= mail_to
		else
			new_mail.junk_mail()

// Mailbag
/obj/item/weapon/storage/bag/mail
	name = "mail bag"
	desc = "A bag for letters, envelopes and other postage."
	icon = 'icons/obj/bureaucracy_rs.dmi'
	icon_state = "mailbag"
	slot_flags = SLOT_BELT | SLOT_POCKET
	w_class = ITEMSIZE_NORMAL
	storage_slots = 21
	max_storage_space = 50 //CHOMPStation PR7051
	max_w_class = ITEMSIZE_NORMAL
	can_hold = list(
		/obj/item/mail,
		/obj/item/smallDelivery,
		/obj/item/weapon/paper
	)

// JUNK MAIL STUFF

/obj/item/mail/junkmail/Initialize()
	. = ..()
	junk_mail()

/obj/item/mail/proc/junk_mail()

	var/obj/junk = /obj/item/weapon/paper/fluff/junkmail_generic
	var/special_name = FALSE

	if(prob(20))
		special_name = TRUE
		junk = pick(list(
			/obj/item/weapon/paper/pamphlet/gateway,
			/obj/item/weapon/paper/pamphlet/violent_video_games,
			/obj/item/weapon/paper/pamphlet/radstorm,
			/obj/item/weapon/paper/fluff/junkmail_redpill,
			/obj/effect/decal/cleanable/ash,
			/obj/item/weapon/paper/fluff/love_letter,
			/obj/item/weapon/reagent_containers/food/snacks/donkpocket/berry,
			/obj/item/weapon/reagent_containers/food/snacks/donkpocket/dankpocket,
			/obj/item/weapon/reagent_containers/food/snacks/donkpocket/gondola,
			/obj/item/weapon/reagent_containers/food/snacks/donkpocket/honk,
			/obj/item/weapon/reagent_containers/food/snacks/donkpocket/pizza,
			/obj/item/weapon/reagent_containers/food/snacks/donkpocket/spicy,
			/obj/item/weapon/reagent_containers/food/snacks/donkpocket/teriyaki,
			/obj/item/toy/figure
		))

	var/list/junk_names = list(
		/obj/item/weapon/paper/pamphlet/gateway = "[initial(name)] for BRAVE adventurers",
		/obj/item/weapon/paper/pamphlet/violent_video_games = "[initial(name)] for the truth about the arcade CentComm doesn't want to hear",
		/obj/item/weapon/paper/pamphlet/radstorm = "[initial(name)] for the threats in space",
		/obj/item/weapon/paper/fluff/junkmail_redpill = "[initial(name)] for those feeling tired working at Nanotrasen",
		/obj/effect/decal/cleanable/ash = "[initial(name)] with INCREDIBLY IMPORTANT ARTIFACT- DELIVER TO SCIENCE DIVISION. HANDLE WITH CARE.",
		/obj/item/weapon/paper/fluff/love_letter = "[initial(name)] for STUPID CARGO MAILMEN.",
		/obj/item/weapon/reagent_containers/food/snacks/donkpocket/berry = "[initial(name)] with NEW BERRY-POCKET.",
		/obj/item/weapon/reagent_containers/food/snacks/donkpocket/dankpocket = "[initial(name)] with NEW DANK-POCKET.",
		/obj/item/weapon/reagent_containers/food/snacks/donkpocket/gondola = "[initial(name)] with NEW GONDOLA-POCKET.",
		/obj/item/weapon/reagent_containers/food/snacks/donkpocket/honk = "[initial(name)] with NEW HONK-POCKET.",
		/obj/item/weapon/reagent_containers/food/snacks/donkpocket/pizza = "[initial(name)] with NEW PIZZA-POCKET.",
		/obj/item/weapon/reagent_containers/food/snacks/donkpocket/spicy = "[initial(name)] with NEW SPICY-POCKET.",
		/obj/item/weapon/reagent_containers/food/snacks/donkpocket/teriyaki = "[initial(name)] with NEW TERIYAKI-POCKET.",
		/obj/item/toy/figure = "[initial(name)] from DoN**K*oC"
	)

	name = special_name ? junk_names[junk] : "important [initial(name)]"

	junk = new junk(src)
	update_icon()
	return TRUE

/obj/item/weapon/paper/fluff/junkmail_generic/Initialize()
	. = ..()
	info = pick(
		prob(5);"Hello! I am executive at Nanotrasen Nigel Takall. Due to accounting error all of my salary is stored in an account unreachable. In order to withdraw I am required to utilize your account to make a deposit to confirm my reality situation. In exchange for a temporary deposit I will give you a payment 1000 credits. All I need is access to your account. Will you be assistant please?",
		prob(5);"Attention. We are contacting you regarding your shuttles' extended warranty. According to our records, the extended warranty on your shuttle has expired. This will leave you vulnerable to unexpected maintenance costs, and may be a violation of planetary law. To regain coverage, please enclose a payment of 1,500 thalers in cash or a money order made out to \"Extended War Aunties, LLC\". Your renewed coverage will be effective once your payment has cleared. A packet containing your extended warranty will arrive within 52 weeks.",
		prob(5);"Triple deposits are waiting for you at MaxBet Online when you register to play with us. You can qualify for a 200% Welcome Bonus at MaxBet Online when you sign up today. Once you are a player with MaxBet, you will also receive lucrative weekly and monthly promotions. You will be able to enjoy over 450 top-flight casino games at MaxBet.",
		prob(5);"Hello !, I'm the former HoS of your deerest station accused by the Nanotrasen of being a traitor . I was the best we had to offer but it seems that nanotramsen has turned their back on me. I need 2000 credits to pay for my bail and then we can restore order on space station 14!",
		prob(5);"Hello, I noticed you riding in a 2555 Ripley and wondered if you'd be interested in selling. Low mileage mechs sell very well in our current market. Please call the number on the back if you're interested",
		prob(5);"Resign Now. I'm on you now. You are fucking with me now Let's see who you are. Watch your back , bitch. Call me.  Don't be afraid, you piece of shit.  Stand up.  If you don't call, you're just afraid. And later: I already know where you live, I'm on you.  You might as well call me. You will see me. I promise.  Bro.",
		prob(5);"Clown Planet Is Going To Become Awesome Possum Again! If This Wasn't Sent To A Clown, Disregard. If This Was Sent To A Mime, Blow It Out Your Ass, Space Frenchie! Anyway! We Make Big Progress On Clown Planet After Stupid Mimes BLOW IT ALL TO SAM HELL!!!!! Sorry I Am Mad.. Anyway Come And Visit, Honkles! We Thought You Were Dead Long Time :^()",
		prob(5);"MONTHPEOPLE ARE REAL, THE NANOTRASEN DEEP STATE DOESN'T WANT YOU TO SEE THIS! I'VE SEEN THEM IN REAL LIFE, THEY HAVE HUGE EYEBALLS AND NO HEAD. THEY'RE SENTIENT CALENDARS. I'M NOT CRAZY. SEARCH THE CALENDAR INCIDENT ON NTNET. USE A PROXY! #BIGTRUTHS #WAKEYWAKEYSPACEMEN #21STOFSEPTEMBER",
		prob(5);"hello :wave::wave: nanotrasens! fuck :point_left::ok_hand: the syndicate! they :older_woman: got ☄ me :heart_eyes::cold_sweat: questioning my :pregnant_woman: loyalty to nanotraben! so :ok_hand::100: please :tired_face: lets :no_entry::eyes: gather our :camera_with_flash::poop: energy :sunglasses: and :moneybag::symbols: QUICK. :astonished: send this :wastebasket::point_left: to :sweat_drops::pill: 10 :joy::joy: other loyal :100: nanotraysens to :sweat_drops::thinking: show we :dog: dont :person_gesturing_no::no_entry_sign: take :shopping_bags: nothing from :joy: the ✝ syndicate!! bless your :point_right_tone2: heart :heart_eyes::broken_heart:",
		prob(5);"Dear employee, CONGRATULATIONS! You've been officially announced by our council to be the Second place prize winner of the Fifteen Million Thaler prize draw sponsored by __Nanotrasen, Reader Digest__ and the **Bigger Billions Jackpot.** We are mandated to find winners that have not claimed their winnings. The total amount you won for the Second place category is **Two Million Thalers**. Congratulations! Please fill out the attached form and provide the Twenty Thousand Thaler processing fee to claim your winnings!",
		prob(5);"Hello, We are unable to validate your billing information for the next billing cycle of your subscription to HONK Weekly therefore we'll suspend your membership if we do not receive a response from you within 48 hours. Obviously we'd love to have you back, simply mail %address% to update your details and continue to enjoy all the best pranks & gags without interruption.",
		prob(5);"Loyal customer, DonkCo Customer Service. We appreciate your brand loyalty support. As such, it is our responsibility and pleasure to inform you of the status of your package. Your package for one \"Moth-Fuzz Parka\" has been delayed. Due to local political tensions, an animal rights group has seized and eaten your package. We appreciate the patience, DonkCo",
		prob(5);"MESSAGE FROM CENTCOMM HIGH COMMAND: DO NOT ACCEPT THE FRIEND REQUEST OF TICKLEBALLS THE CLOWN. HE IS NOT FUNNY AND ON TOP OF THAT HE WILL HACK YOUR NTNET ACCOUNT AND MAKE YOU UNFUNNY TOO. YOU WILL LOSE ALL YOUR SPACECREDITS!!!!! SPREAD THE WORD. ANYONE WHO BECOMES FRIENDS WITH TINKLEBALLS THE CLOWN IS GOING TO LOSE ALL OF THEIR SPACECREDITS AND LOOK LIKE A HUGE IDIOT.",
		prob(5);"i WAS A NORMAL BOY AND I CAME HOME FROM SCHOOL AND I WANTED TO PLAY SOME ORION TRAIL WHICH IS A VERY FUN GAME BUT WHEN WENT TO ARCADE MACHINE SOMETHING WAS WEIRD TEH LOGO HASD BLOD IN IT AND I BECAME VERY SCARE AND I CHECK OPTIONS AND TEHRES ONLY 1 \"GO BACK\" I CKLICK IT AND I SEE CHAT  SI EMPTY THERE'S ONLY ONE CHARACTER CALLED \"CLOSE TEH GAME  \" AND I GO TO ANOTHER MACHINE AND PLAY THERE BUT WHEN I PLAY GAME IS FULL OF BLOOD AND DEAD BODIES FROM SPACEMAN LOOK CLOSER AND SEE CLOWN AND CLOWN COMES CLOSER AND LOOKS AT ME AND SAYS \"DON'T SAY I DIKDNT' WWARN YOU\" AND CLOWN CLOSEUP APPEARS WITH BLOOD-RED HYPERREALISTIC EYES AND HE TELLS ME \"YOU WILL BE THE NEXT ONE\" AND ARCADE MACHINE POWER SHUT OFF AND THAT NITE CLOWN APPEAR AT MY WINDOW AND KILL ME AT 3 AM AND NOW IM DEAD AND YOU WILL BE TRHNE NEXT OEN UNLESS YOU PASTE THIS STORY TO 10 NTNET FRIENDS",
		)

/obj/item/weapon/paper/fluff/junkmail_redpill
	name = "smudged paper"
	icon_state = "scrap"

/obj/item/weapon/paper/fluff/junkmail_redpill/Initialize()
	. = ..()
	info = "You need to escape the simulation. Don't forget the numbers, they help you remember: '[rand(0,9)]*[rand(0,9)][rand(0,9)]...'"

/obj/item/weapon/paper/fluff/love_letter
	name = "love letter"
	icon_state = "paper_words"

/obj/item/weapon/paper/fluff/love_letter/Initialize()
	. = ..()
	info = "I HATE CARGO MAIL\n\"GRAA LEMME BREAK YOUR DOORS DOWN I GOTTA GIVE YOU MAIL\nREE YOU GOTTA GET YOUR MAIL I SORTED IT\nYOU'RE WASTIN YOUR TIME IF YOU DONT GET MAIL YOU NEED TO GET YOUR MAIL NOW\nWHY ARENT YO UGETTING YOUR MAIL RAAA\""

/obj/item/weapon/paper/fluff/junkmail_generic
	name = "important document"
	icon_state = "paper_words"
