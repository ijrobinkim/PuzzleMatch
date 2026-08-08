extends "res://addons/gut/test.gd"

func test_all_30_levels_load_and_validate() -> void:
	var json_file := FileAccess.open("res://resources/levels/level_table.json", FileAccess.READ)
	assert_not_null(json_file, "level_table.json should exist and be readable")
	if json_file == null:
		return

	var text := json_file.get_as_text()
	json_file.close()

	var json := JSON.new()
	var err := json.parse(text)
	assert_eq(err, OK, "level_table.json should be valid JSON")

	var data_array = json.data
	assert_eq(typeof(data_array), TYPE_ARRAY)
	assert_eq(data_array.size(), 30, "Should contain exactly 30 stages")

	for i in range(1, 31):
		var level_id_str := "level_%03d" % i
		
		# 1. Test Godot Resource (.tres) loading
		var tres_path := "res://resources/levels/%s.tres" % level_id_str
		var tres_res: LevelData = load(tres_path)
		assert_not_null(tres_res, "Tres level file %s should load successfully" % tres_path)
		if tres_res:
			assert_eq(tres_res.level_id, level_id_str)
			assert_gt(tres_res.move_limit, 0, "Move limit should be greater than 0")
			assert_gt(tres_res.objective, 0, "Objective score should be greater than 0")

		# 2. Test JSON Table conversion via LevelData.from_dictionary
		var dict_data: Dictionary = data_array[i - 1]
		var level_from_json := LevelData.from_dictionary(dict_data)
		assert_not_null(level_from_json)
		assert_eq(level_from_json.level_id, level_id_str)
		assert_eq(level_from_json.move_limit, tres_res.move_limit)
