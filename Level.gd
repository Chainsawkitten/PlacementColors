extends Node2D

# Preload piece scene.
var pieceScene = preload("Piece.tscn")

# All the chess pieces.
var pieces = []
var pieces_node

# The board node.
var board

# The size of a cell in the grid.
var grid_size = 256

# Level description (tutorial text).
var description = " "

# Whether the level has been solved.
var solved = false
var all_on_board = false

# Colors used.
var white = Color(1.0, 1.0, 1.0, 1.0)

# Whether a piece has been moved.
var piece_moved = false

# Amount of pieces that aren't blocks.
var non_block_pieces = 0

# Current save file version.
const save_version = 1

# Initialization.
func _ready():
	board = get_node("Board")
	board.set_board_size(Vector2(3, 3))
	
	pieces_node = get_node("Pieces")
	
	set_process(true)

# Called every frame.
func _process(delta):
	# Handle moved pieces.
	var moved =  false
	for piece in pieces:
		if piece.has_moved():
			piece.clear_moved()
			moved = true
			piece_moved = true
			
			if !global.get_editor():
			# Check that the piece is within bounds
				var pos = piece.get_target_position() / grid_size
				if pos.x < 0 or pos.x >= board.get_board_size().x or pos.y < 0 or pos.y >= board.get_board_size().y:
					piece.reset_position()
			
				# Check that there are no collisions.
				for piece2 in pieces:
					if piece != piece2 and piece.get_target_position() == piece2.get_target_position():
						if piece2.get_type() != 7:
							piece2.reset_position()
						else:
							piece.reset_position()
	
	# Check whether the level has been cleared.
	if moved:
		solved = check_solved()
		color_pieces()
	
	# Clear highlighted pieces.
	for piece in pieces:
		piece.set_highlighted(false)
	
	# Show which pieces protect a hovered piece.
	if all_on_board:
		for piece in pieces:
			if !piece.moving and piece.hover and !piece.is_valid():
				var cell = board.get_cell(piece.get_target_position())
				for protector in cell.protectors[piece.get_color()]:
					protector.set_highlighted(true)
	
	var desc_node = get_node("DescriptionLabel")
	var zoom = global.get_zoom()
	desc_node.set_size(Vector2(2000 * zoom, 800 * zoom))
	desc_node.get_font("font").set_size(84 * zoom)
	desc_node.set_pos(Vector2((board.get_board_size().x * grid_size - 2000) / 2, (board.get_board_size().y + 1) * grid_size))
	desc_node.set_scale(Vector2(1 / zoom, 1 / zoom))

# Save the level to a file.
#  filename - name of the file to save
func save_level(filename):
	var file = File.new()
	file.open(filename, File.WRITE)
	
	# Save board size.
	file.store_32(board.get_board_size().x)
	file.store_32(board.get_board_size().y)
	
	# Save pieces.
	file.store_32(pieces.size())
	for piece in pieces:
		file.store_32(piece.get_target_position().x / grid_size)
		file.store_32(piece.get_target_position().y / grid_size)
		file.store_32(piece.get_type())
		file.store_32(piece.get_color())
	
	# Save description.
	file.store_pascal_string(description)
	
	file.close()

# Load a level from file.
#  filename - name of the file to load
func load_level(filename):
	# Clear pieces.
	for piece in pieces:
		pieces_node.remove_child(piece)
	pieces.clear()
	solved = false
	
	var file = File.new()
	file.open(filename, File.READ)
	
	# Load board size.
	var board_size = Vector2(0, 0)
	board_size.x = file.get_32()
	board_size.y = file.get_32()
	board.set_board_size(board_size)
	
	# Load pieces.
	var pieceCount = 0
	var amount = file.get_32()
	for i in range(amount):
		var x = file.get_32()
		var y = file.get_32()
		var type = file.get_32()
		var color = file.get_32()
		var piece = add_piece(type, color)
		if global.get_editor() or type == 7:
			var p = Vector2(x, y) * grid_size
			piece.set_pos(p)
			piece.set_target_position(p)
		else:
			pieceCount += 1
	
	non_block_pieces = pieceCount
	
	# Set initial positions. Sort based on color and type.
	var pieceIndex = 0
	for color in range(2):
		for type in range(1,7):
			for i in range(amount):
				if pieces[i].color == color and pieces[i].type == type:
					pieces[i].set_initial_position(Vector2(-2 - floor(pieceIndex / board.get_board_size().y), pieceIndex % int(board.get_board_size().y)) * grid_size)
					pieceIndex += 1
	
	# Load description.
	set_description(file.get_pascal_string())
	
	file.close()

# Add a piece to the level.
#  type - the type of the piece
#  color - the color of the piece
# Returns the added piece.
func add_piece(type, color):
	var piece = pieceScene.instance()
	pieces_node.add_child(piece)
	piece.set_type(type)
	piece.set_color(color)
	pieces.append(piece)
	return piece

# Remove all pieces from the level.
func clear_pieces():
	for piece in pieces:
		pieces_node.remove_child(piece)
	pieces.clear()

# Set the size of the board.
#  size - the size of the board
func set_board_size(size):
	board.set_board_size(size)

# Get the size of the board in pixels.
func get_level_size():
	return board.get_board_size() * grid_size

# Check whether the level has been solved.
func check_solved():
	# Clear previous solved state.
	board.clear()
	
	if !all_pieces_on_board():
		return false
	
	# Check if all pieces are protected once.
	return board.check_solved()

# Check whether all pieces are on the board.
func all_pieces_on_board():
	all_on_board = true
	for piece in pieces:
		if !board.add_piece(piece):
			all_on_board = false
			return false
	return true

# Get whether the level has been solved.
func is_solved():
	return solved

# Set the level's description.
#  text - the description
func set_description(text):
	description = text
	get_node("DescriptionLabel").set_text(text)

# Save current level placement.
#  filename - name of the file to store the placement in
func save_placement(filename):
	var file = File.new()
	file.open(filename, File.WRITE)
	
	file.store_32(save_version)
	
	for piece in pieces:
		file.store_double(piece.get_target_position().x / 4)
		file.store_double(piece.get_target_position().y / 4)
	
	file.close()

# Load piece placement from file.
#  filename - name of the file to load the placement from
func load_placement(filename):
	var file = File.new()
	if file.file_exists(filename):
		file.open(filename, File.READ)
		
		var version = file.get_32()
		if version > save_version:
			file.close()
			return
		
		for piece in pieces:
			var x = 4 * file.get_double()
			var y = 4 * file.get_double()
			if piece.type != 7:
				piece.set_pos(Vector2(x, y))
				piece.set_target_position(Vector2(x, y))
		
		file.close()
	
	check_solved()
	color_pieces()

# Color pieces.
func color_pieces():
	# Color all pieces black.
	for piece in pieces:
		if piece.get_type() != 7:
			piece.set_valid(true)
		else:
			piece.set_modulate(white)
	
	# Check if all pieces on board.
	if all_on_board:
		# Color invalid pieces red.
		for piece in pieces:
			if piece.get_type() != 7 and !board.is_valid(piece):
				piece.set_valid(false)
