
extends Control

var is_processing := false



func _on_log_in_b_pressed() -> void:
	if is_processing:
		return

	var email: String = $CanvasLayer/Username_EDIT.text.strip_edges()
	var password: String = $CanvasLayer/Password_EDIT.text

	if email.is_empty() or password.is_empty():
		print("Enter your email and password.")
		return

	is_processing = true

	# Authenticate an existing account.
	var task = Supabase.auth.sign_in(email, password)
	await task.completed

	if task.error:
		print("Login failed: ", task.error.message)
		is_processing = false
		return

	if task.user == null:
		print("Login failed: no user returned.")
		is_processing = false
		return

	print("Login successful: ", task.user.id)

	# Retrieve the player's saved data.
	var query = SupabaseQuery.new().from("profiles").select().eq(
		"id", str(task.user.id)
	)

	var result = await Supabase.database.query(query).completed

	if result.error:
		print("Failed to load player data: ", result.error.message)
	elif result.data.is_empty():
		print("No player profile found.")
	else:
		var profile: Dictionary = result.data[0]

		print("Welcome back, ", profile["player_name"])
		print("Coins: ", profile["coins"])
		print("Level: ", profile["level"])
		print("XP: ", profile["xp"])

	is_processing = false


func _on_sign_in_b_pressed() -> void:
	if is_processing:
		return

	var email: String = $CanvasLayer/Username_EDIT.text.strip_edges()
	var password: String = $CanvasLayer/Password_EDIT.text
	var player_name: String = $CanvasLayer/PlayerName_EDIT.text.strip_edges()

	if email.is_empty() or password.is_empty() or player_name.is_empty():
		print("Enter your email, password, and player name.")
		return

	is_processing = true

	# Create a new Supabase authentication account.
	var task = Supabase.auth.sign_up(email, password)
	await task.completed

	if task.error:
		print("Sign-up failed: ", task.error.message)
		is_processing = false
		return

	if task.user == null:
		print("Account created, but no user was returned.")
		print("Email confirmation may be required.")
		is_processing = false
		return

	print("Account created: ", task.user.id)

	# A session may not exist yet if email confirmation is enabled.
	# The profile insert requires an authenticated session.
	var profile_task = SupabaseQuery.new().from("profiles").insert([
	{
		"id": str(task.user.id),
		"player_name": player_name,
		"coins": 0,
		"level": 1,
		"xp": 0}])

	var profile_result = await Supabase.database.query(
		profile_task
	).completed

	if profile_result.error:
		print("Profile creation failed: ", profile_result.error.message)
	else:
		print("Player profile created successfully!")

	is_processing = false
	pass # Replace with function body.
