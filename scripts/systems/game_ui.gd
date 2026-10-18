extends Control

@onready var text_label: RichTextLabel = $CanvasLayer/RichTextLabel# Using the % Unique Name fix

@export var typing_speed: float = 0.05

func play_typewriter_effect(text_to_type: String) -> void:
	# 1. Use RegEx to split the string by sentence-ending punctuation safely
	var regex = RegEx.new()
	# This pattern finds periods, question marks, or exclamation marks followed by a space or end of string
	regex.compile("[^.!?]+[.!?]?") 
	
	var sentences: Array = []
	for result in regex.search_all(text_to_type):
		sentences.append(result.get_string().strip_edges())
		
	# 2. Loop through each complete sentence one by one
	for sentence in sentences:
		if sentence.is_empty():
			continue
			
		# Set text and clear screen instantly for the new sentence
		text_label.text = sentence
		text_label.visible_characters = 0
		
		# 3. Type out the current sentence letter-by-letter
		for i in range(sentence.length()):
			text_label.visible_characters += 1
			
			# Natural human pacing within the sentence
			var current_letter = sentence[i]
			var wait_time = typing_speed
			if current_letter in [",", ";", "-"]: 
				wait_time = 0.2
				
			await get_tree().create_timer(wait_time).timeout
			
		# 4. Long dramatic pause at the end of the sentence before it vanishes
		await get_tree().create_timer(1.2).timeout
