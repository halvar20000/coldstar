class_name SoundTest
extends Node
## Plays every clip in turn and reports what loaded. Run windowed to hear it,
## headless to check that nothing is missing or zero-length:
##   Godot --headless --path . -- --soundtest

func run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("--- sound test ---")
	var fails := 0
	for clip: String in Audio.CLIPS:
		var stream: AudioStream = Audio.streams.get(clip)
		if stream == null:
			print("  FAIL %-20s missing" % clip)
			fails += 1
			continue
		var length := stream.get_length()
		var looping := clip in Audio.LOOPING
		var ok := length > 0.02
		if not ok:
			fails += 1
		print("  %s %-20s %5.2fs%s" % ["PASS" if ok else "FAIL", clip, length,
			"  (loops)" if looping else ""])
		Audio.play_ui(clip, -6.0)
		await get_tree().create_timer(minf(length, 1.6) + 0.15).timeout
	print("--- sound test: %s ---" % ("all clips loaded" if fails == 0 else "%d FAILED" % fails))
	# Stop anything still sounding, or the engine reports leaked players at exit.
	for child in Audio.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
	await get_tree().process_frame
	get_tree().quit(1 if fails > 0 else 0)
